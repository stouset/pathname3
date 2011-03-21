require 'fileutils'
require 'find'

#
# Pathname represents a path to a file on a filesystem. It can be relative or
# absolute. It exists to provide a more instance-oriented approach to managing
# paths than the class-level methods on File, FileTest, Dir, and Find.
#
class Pathname < String
  SYMLOOP_MAX = 8 # deepest symlink traversal

  ROOT    = '/'.freeze
  DOT     = '.'.freeze
  DOT_DOT = '..'.freeze

  #
  # Creates a new Pathname. Any path with a null is rejected.
  #
  def initialize(path)
    if path =~ %r{\0}
      raise ArgumentError, "path cannot contain ASCII NULLs"
    end

    super(path)
  end

  #
  # Compares pathnames, case-sensitively. Sorts directories higher than other
  # files named similarly.
  #
  def <=>(other)
    self.tr('/', "\0").to_s <=> other.to_str.tr('/', "\0")
  rescue NoMethodError # doesn't respond to to_str
    nil
  end

  #
  # Compares two pathnames for equality. Considers pathnames equal if they
  # both point to the same location, and are both absolute or both relative.
  #
  def ==(other)
    left  =                 self.cleanpath.tr('/', "\0").to_s
    right = other.to_str.to_path.cleanpath.tr('/', "\0").to_s

    left == right
  rescue NoMethodError # doesn't implement to_str
    false
  end

  #
  # Appends a component of a path to self. Returns a Pathname to the combined
  # path. Cleans any redundant components of the path.
  #
  def +(path)
    dup << path
  end

  #
  # Appends (destructively) a component of a path to self. Replaces the
  # contents of the current Pathname with the new, combined path. Cleans any
  # redundant components of the path.
  #
  def <<(path)
    replace( join(path).cleanpath! )
  end

  #
  # Returns true if this is an absolute path.
  #
  def absolute?
    self[0, 1].to_s == ROOT
  end

  #
  # Yields to each component of the path, going up to the root.
  #
  #   Pathname.new('/path/to/some/file').ascend {|path| p path }
  #     "/path/to/some/file"
  #     "/path/to/some"
  #     "/path/to"
  #     "/path"
  #     "/"
  #
  #   Pathname.new('a/relative/path').ascend {|path| p path }
  #     "a/relative/path"
  #     "a/relative"
  #     "a"
  #
  #  Does not actually access the filesystem.
  #
  def ascend
    parts = to_a
    parts.length.downto(1) do |i|
      yield self.class.join(parts[0, i])
    end
  end

  #
  # Returns all children of this path. "." and ".." are not included, since
  # they aren't under the current path.
  #
  def children
    entries[2..-1]
  end

  #
  # Cleans the path by removing consecutive slashes, and useless dots.
  # Replaces the contents of the current Pathname.
  #
  def cleanpath!
    parts = to_a
    final = []

    parts.each do |part|
      case part
        when DOT     then next
        when DOT_DOT then
          case final.last
            when ROOT    then next
            when DOT_DOT then final.push(DOT_DOT)
            when nil     then final.push(DOT_DOT)
            else              final.pop
          end
        else final.push(part)
      end
    end

    replace(final.empty? ? DOT : self.class.join(*final))
  end

  #
  # Cleans the path by removing consecutive slashes, and useless dots.
  #
  def cleanpath
    dup.cleanpath!
  end

  #
  # Yields to each component of the path, going down from the root.
  #
  #   Pathname.new('/path/to/some/file').descend {|path| p path }
  #     "/"
  #     "/path"
  #     "/path/to"
  #     "/path/to/some"
  #     "/path/to/some/file"
  #
  #   Pathname.new('a/relative/path').descend {|path| p path }
  #     "a"
  #     "a/relative"
  #     "a/relative/path"
  #
  #  Does not actually access the filesystem.
  #
  def descend
    parts = to_a
    1.upto(parts.length) do |i|
      yield self.class.join(parts[0, i])
    end
  end

  #
  # Returns true if this path is simply a '.'.
  #
  def dot?
    self == DOT
  end

  #
  # Returns true if this path is simply a '..'.
  #
  def dot_dot?
    self == DOT_DOT
  end

  #
  # Iterates over every component of the path.
  #
  #   Pathname.new('/path/to/some/file').each_filename {|path| p path }
  #     "/"
  #     "path"
  #     "to"
  #     "some"
  #     "file"
  #
  #   Pathname.new('a/relative/path').each_filename {|part| p part }
  #     "a"
  #     "relative"
  #     "path"
  #
  def each_filename(&blk)
    to_a.each(&blk)
  end

  #
  # Returns true if the path is a mountpoint.
  #
  def mountpoint?
    stat1 = self.lstat
    stat2 = self.parent.lstat

    stat1.dev != stat2.dev || stat1.ino == stat2.ino
  rescue Errno::ENOENT
    false
  end

  #
  # Returns a path to the parent directory. Simply appends a "..".
  #
  def parent
    self + '..'
  end

  #
  # Resolves a path to locate a real location on the filesystem. Resolves
  # symlinks up to a depth of SYMLOOP_MAX.
  #
  def realpath
    path = self

    SYMLOOP_MAX.times do
      link = path.readlink
      link = path.dirname + link if link.relative?
      path = link
    end

    raise Errno::ELOOP, self
  rescue Errno::EINVAL
    path.expand_path
  end

  #
  # Returns true if this is a relative path.
  #
  def relative?
    !absolute?
  end

  #
  # Returns this path as a relative location from +base+. The path and +base+
  # must both be relative or both be absolute. An ArgumentError is raised if
  # a relative path can't be generated between the two locations.
  #
  # Does not access the filesystem.
  #
  def relative_path_from(base)
    base = base.to_path

    # both must be relative, or both must be absolute
    if self.absolute? != base.absolute?
      raise ArgumentError, 'no relative path between a relative and absolute'
    end

    return self        if base.dot?
    return DOT.to_path if self == base

    base = base.cleanpath.to_a
    dest = self.cleanpath.to_a

    while !dest.empty? && !base.empty? && dest[0] == base[0]
      base.shift
      dest.shift
    end

    base.shift if base[0] == DOT
    dest.shift if dest[0] == DOT

    if base.include?(DOT_DOT)
      raise ArgumentError, "base directory may not contain '#{DOT_DOT}'"
    end

    path = base.fill(DOT_DOT) + dest
    path = self.class.join(*path)
    path = DOT.to_path if path.empty?

    path
  end

  #
  # Returns true if this path points to the root of the filesystem.
  #
  def root?
    !!(self =~ %r{^#{ROOT}+$})
  end

  #
  # Splits the path into an array of its components.
  #
  def to_a
    array = to_s.split(File::SEPARATOR)
    array.delete('')
    array.insert(0, ROOT) if absolute?
    array
  end

  #
  # Returns self.
  #
  def to_path
    self
  end

  #
  # Unlinks the file or directory at the path.
  #
  def unlink
    Dir.unlink(self)
    true
  rescue Errno::ENOTDIR
    File.unlink(self)
    true
  end
end

class Pathname
  # See Dir::[]
  def self.[](pattern); Dir[pattern].map! {|d| d.to_path }; end

  # See Dir::pwd
  def self.pwd; Dir.pwd.to_path; end

  # See Dir::entries
  def entries; Dir.entries(self).map! {|e| e.to_path }; end

  # See Dir::mkdir
  def mkdir(mode = 0777); Dir.mkdir(self, mode); end

  # See Dir::open
  def opendir(&blk); Dir.open(self, &blk); end

  # See Dir::rmdir
  def rmdir; Dir.rmdir(self); end

  # See Dir::glob
  def self.glob(pattern, flags = 0)
    dirs = Dir.glob(pattern, flags)
    dirs.map! {|path| path.to_path }

    if block_given?
      dirs.each {|dir| yield dir }
      nil
    else
      dirs
    end
  end

  # See Dir::glob
  def glob(pattern, flags = 0, &block)
    patterns = [pattern].flatten
    patterns.map! {|p| self.class.glob(self.to_s + p, flags, &block) }
    patterns.flatten
  end

  # See Dir::chdir
  def chdir
    blk = lambda { yield self } if block_given?
    Dir.chdir(self, &blk)
  end
end

class Pathname
  # See FileTest::blockdev?
  def blockdev?; FileTest.blockdev?(self); end

  # See FileTest::chardev?
  def chardev?; FileTest.chardev?(self); end

  # See FileTest::directory?
  def directory?; FileTest.directory?(self); end

  # See FileTest::executable?
  def executable?; FileTest.executable?(self); end

  # See FileTest::executable_real?
  def executable_real?; FileTest.executable_real?(self); end

  # See FileTest::exists?
  def exists?; FileTest.exists?(self); end

  # See FileTest::file?
  def file?; FileTest.file?(self); end

  # See FileTest::grpowned?
  def grpowned?; FileTest.grpowned?(self); end

  # See FileTest::owned?
  def owned?; FileTest.owned?(self); end

  # See FileTest::pipe?
  def pipe?; FileTest.pipe?(self); end

  # See FileTest::readable?
  def readable?; FileTest.readable?(self); end

  # See FileTest::readable_real?
  def readable_real?; FileTest.readable_real?(self); end

  # See FileTest::setgid?
  def setgid?; FileTest.setgit?(self); end

  # See FileTest::setuid?
  def setuid?; FileTest.setuid?(self); end

  # See FileTest::socket?
  def socket?; FileTest.socket?(self); end

  # See FileTest::sticky?
  def sticky?; FileTest.sticky?(self); end

  # See FileTest::symlink?
  def symlink?; FileTest.symlink?(self); end

  # See FileTest::world_readable?
  def world_readable?; FileTest.world_readable?(self); end

  # See FileTest::world_writable?
  def world_writable?; FileTest.world_writable?(self); end

  # See FileTest::writable?
  def writable?; FileTest.writable?(self); end

  # See FileTest::writable_real?
  def writable_real?; FileTest.writable_real?(self); end

  # See FileTest::zero?
  def zero?; FileTest.zero?(self); end
end

class Pathname
  # See File::atime
  def atime; File.atime(self); end

  # See File::ctime
  def ctime; File.ctime(self); end

  # See File::ftype
  def ftype; File.ftype(self); end

  # See File::lstat
  def lstat; File.lstat(self); end

  # See File::mtime
  def mtime; File.mtime(self); end

  # See File::stat
  def stat; File.stat(self); end

  # See File::utime
  def utime(atime, mtime); File.utime(self, atime, mtime); end
end

class Pathname
  # See File::join
  def self.join(*parts); File.join(*parts.reject {|p| p.empty? }).to_path; end

  # See File::basename
  def basename; File.basename(self).to_path; end

  # See File::chmod
  def chmod(mode); File.chmod(mode, self); end

  # See File::chown
  def chown(owner, group); File.chown(owner, group, self); end

  # See File::dirname
  def dirname; File.dirname(self).to_path; end

  # See File::expand_path
  def expand_path(from = nil); File.expand_path(self, from).to_path; end

  # See File::extname
  def extname; File.extname(self); end

  # See File::fnmatch
  def fnmatch?(pat, flags = 0); File.fnmatch(pat, self, flags); end

  # See File::join
  def join(*parts); self.class.join(self, *parts); end

  # See File::lchmod
  def lchmod(mode); File.lchmod(mode, self); end

  # See File::lchown
  def lchown(owner, group); File.lchown(owner, group, self); end

  # See File::link
  def link(to); File.link(self, to); end

  # See File::open
  def open(mode = 'r', perm = nil, &blk); File.open(self, mode, perm, &blk); end

  # See File::readlink
  def readlink; File.readlink(self).to_path; end

  # See File::rename
  def rename(to); File.rename(self, to); replace(to); end

  # See File::size
  def size; File.size(self); end

  # See File::size?
  def size?; File.size?(self); end

  # See File::split
  def split; File.split(self).map {|part| part.to_path }; end

  # See File::symlink
  def symlink(to); File.symlink(self, to); end

  # See File::truncate
  def truncate; File.truncate(self); end
end

class Pathname
  # See FileUtils::mkpath
  def mkpath; FileUtils.mkpath(self).first.to_path; end

  # See FileUtils::rmtree
  def rmtree; FileUtils.rmtree(self).first.to_path; end

  # See FileUtils::touch
  def touch; FileUtils.touch(self).first.to_path; end
end

class Pathname
  # See IO::each_line
  def each_line(sep = $/, &blk); IO.foreach(self, sep, &blk); end

  # See IO::read
  def read(len = nil, off = 0); IO.read(self, len, off); end

  # See IO::readlines
  def readlines(sep = $/); IO.readlines(self, sep); end

  # See IO::sysopen
  def sysopen(mode = 'r', perm = nil); IO.sysopen(self, mode, perm); end
end

class Pathname
  # See Find::find
  def find; Find.find(self) {|path| yield path.to_path }; end
end

class Pathname
  class << self
    alias getwd pwd
  end

  alias absolute expand_path
  alias delete   unlink
  alias exist?   exists?
  alias fnmatch  fnmatch?
end

class String
  #
  # Converts the string directly to a pathname.
  #
  def to_path
    Pathname.new(self)
  end
end

module Kernel
  #
  # Allows construction of a Pathname by using the class name as a method.
  #
  # This really ought to be deprecated due to String#to_path.
  #
  def Pathname(path)
    Pathname.new(path)
  end
end
