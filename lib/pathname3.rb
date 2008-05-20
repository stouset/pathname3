require 'fileutils'
require 'find'

#
# Pathname represents a path to a file on a filesystem. It can be relative or
# absolute. It exists to provide a more instance-oriented approach to managing
# paths than the class-level methods on File, FileTest, Dir, and Find.
#
class Pathname < String
  VERSION     = '1.1.0' # version of the library
  SYMLOOP_MAX = 8       # deepest symlink traversal
  
  ROOT    = Pathname.new('/').freeze
  DOT     = Pathname.new('.').freeze
  DOT_DOT = Pathname.new('..').freeze
  
  include Comparable
  
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
    to_s.tr('/', "\0") <=> other.to_s.tr('/', "\0")
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
    self[0, 1] == ROOT
  end
  
  #
  # Yields to each component of the path, going up to the root.
  #
  #    Pathname.new('/path/to/some/file').ascend {|path| p path }
  #      "/path/to/some/file"
  #      "/path/to/some"
  #      "/path/to"
  #      "/path"
  #      "/"
  #
  #    Pathname.new('a/relative/path').ascend {|path| p path }
  #      "a/relative/path"
  #      "a/relative"
  #      "a"
  #
  #  Does not actually access the filesystem.
  #
  def ascend
    parts = to_a
    parts.length.downto(1) do |i|
      yield self.class.join(parts[0, i])
    end
  end
  
  def children
    entries[2..-1]
  end
  
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
  
  def cleanpath
    dup.cleanpath!
  end
  
  def descend
    parts = to_a
    1.upto(parts.length) do |i|
      yield self.class.join(parts[0, i])
    end
  end
  
  def dot?
    self == DOT
  end
  
  def dot_dot?
    self == DOT_DOT
  end
  
  def each_filename(&blk)
    to_a.each(&blk)
  end
  
  def mountpoint?
    stat1 = self.lstat
    stat2 = self.parent.lstat
    
    stat1.dev != stat2.dev || stat1.ino == stat2.ino
  rescue Errno::ENOENT
    false
  end
  
  def parent
    self + '..'
  end
  
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
  
  def relative?
    !absolute?
  end
  
  def relative_path_from(base)
    base = base.to_path
    
    # both must be relative, or both must be absolute
    if self.absolute? != base.absolute?
      raise ArgumentError, 'no relative path between a relative and absolute'
    end
    
    return self    if base.dot?
    return DOT     if self == base
    
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
    path = DOT.dup if path.empty?
    
    path
  end
  
  def root?
    !!(self =~ %r{^#{ROOT}+$})
  end
  
  def to_a
    array = to_s.split(File::SEPARATOR)
    array.delete('')
    array.insert(0, ROOT) if absolute?
    array
  end
  
  def to_path
    self
  end
  
  def unlink
    Dir.unlink(self)
  rescue Errno::ENOTDIR
    File.unlink(self)
  end
end

class Pathname
  def self.[](pattern);   Dir[pattern].map! {|d| d.to_path };      end
  def self.pwd;           Dir.pwd.to_path;                         end
  def entries;            Dir.entries(self).map! {|e| e.to_path }; end
  def mkdir(mode = 0777); Dir.mkdir(self, mode);                   end
  def open(&blk);         Dir.open(self, &blk);                    end
  def rmdir;              Dir.rmdir(self);                         end
  
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
  
  def chdir 
    blk = lambda { yield self } if block_given?
    Dir.chdir(self, &blk)
  end
end

class Pathname
  def blockdev?;        FileTest.blockdev?(self);        end
  def chardev?;         FileTest.chardev?(self);         end
  def directory?;       FileTest.directory?(self);       end
  def executable?;      FileTest.executable?(self);      end
  def executable_real?; FileTest.executable_real?(self); end
  def exists?;          FileTest.exists?(self);          end
  def file?;            FileTest.file?(self);            end
  def grpowned?;        FileTest.grpowned?(self);        end
  def owned?;           FileTest.owned?(self);           end
  def pipe?;            FileTest.pipe?(self);            end
  def readable?;        FileTest.readable?(self);        end
  def readable_real?;   FileTest.readable_real?(self);   end
  def setgid?;          FileTest.setgit?(self);          end
  def setuid?;          FileTest.setuid?(self);          end
  def size;             FileTest.size(self);             end
  def size?;            FileTest.size?(self);            end
  def socket?;          FileTest.socket?(self);          end
  def sticky?;          FileTest.sticky?(self);          end
  def symlink?;         FileTest.symlink?(self);         end
  def world_readable?;  FileTest.world_readable?(self);  end
  def world_writable?;  FileTest.world_writable?(self);  end
  def writable?;        FileTest.writable?(self);        end
  def writable_real?;   FileTest.writable_real?(self);   end
  def zero?;            FileTest.zero?(self);            end
end

class Pathname
  def atime;               File.atime(self);               end
  def ctime;               File.ctime(self);               end
  def ftype;               File.ftype(self);               end
  def lstat;               File.lstat(self);               end
  def mtime;               File.mtime(self);               end
  def stat;                File.stat(self);                end
  def utime(atime, mtime); File.utime(self, atime, mtime); end
end

class Pathname
  def self.join(*parts);         File.join(*parts).to_path;            end
  def basename;                  File.basename(self).to_path;          end
  def chmod(mode);               File.chmod(mode, self);               end
  def chown(owner, group);       File.chown(owner, group, self);       end
  def dirname;                   File.dirname(self).to_path;           end
  def expand_path(from = nil);   File.expand_path(self, from).to_path; end
  def extname;                   File.extname(self);                   end
  def fnmatch?(pat, flags = 0);  File.fnmatch(pat, self, flags);       end
  def join(*parts);              File.join(self, *parts).to_path;      end
  def lchmod(mode);              File.lchmod(mode, self);              end
  def lchown(owner, group);      File.lchown(owner, group, self);      end
  def link(to);                  File.link(self, to);                  end
  def mkpath;                    File.makedirs(self);                  end
  def readlink;                  File.readlink(self).to_path;          end
  def rename(to);                File.rename(self, to); replace(to);   end
  def split;                     File.split(self);                     end
  def symlink(to);               File.symlink(self, to);               end
  def truncate;                  File.truncate(self);                  end
end

class Pathname
  def rmtree; FileUtils.rmtree(self); end
  def touch;  FileUtils.touch(self);  end
end

class Pathname
  def each_line(sep = $/, &blk);       IO.foreach(self, sep, &blk);  end
  def open(mode = 'r', &blk);          IO.open(self, mode, &blk);    end
  def read(len = nil, off = 0);        IO.read(self, len, off);      end
  def readlines(sep = $/);             IO.readlines(self, sep);      end
  def sysopen(mode = 'r', perm = nil); IO.sysopen(self, mode, perm); end
end

class Pathname
  def find; Find.find(self) {|path| yield path.to_path }; end
end

class Pathname
  class << self
    alias getwd pwd
  end
  
  alias delete   unlink
  alias exist?   exists?
  alias fnmatch  fnmatch?
end

class String
  def to_path
    Pathname.new(self)
  end
end

module Kernel
  def Pathname(path)
    Pathname.new(path)
  end
end
