require 'find'

class Pathname < String
  VERSION = '1.0.0'
  ROOT    = Pathname.new('/')
  
  def self.[](pattern)
    Dir[pattern].map! {|d| d.to_path }
  end
  
  def self.pwd
    Dir.pwd.to_path
  end
  
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
  
  class << self
    alias getwd pwd
  end
  
  def +(path)
    dup << path
  end
  
  def <<(path)    
    replace( join(path) )
  end
  
  def absolute?
    self[0, 1] == ROOT
  end
  
  def ascend
    if root?
      yield ROOT
    else
      parts = to_a
      parts.length.downto(1) do |i|
        yield File.join(parts[0, i]).to_path
      end
    end
  end
  
  def atime
    File.atime(self)
  end
  
  def basename
    File.basename(self).to_path
  end
  
  def blockdev?
    File.blockdev?(self)
  end
  
  def chardev?
    File.chardev?(self)
  end
  
  def chdir
    case block_given?
      when true then Dir.chdir(self) { yield self }
      else           Dir.chdir(self)
    end
  end
  
  def children
    entries[2..-1]
  end
  
  def chmod(mode)
    File.chmod(mode, self)
  end
  
  def chown(owner, group)
    File.chown(owner, group, self)
  end
  
  def cleanpath!
    parts = to_a
    final = []
    
    parts.each do |part|
      case part
        when '.'  then next
        when '..' then 
          final.push('..') if     final.empty?
          final.pop        unless %w{ / .. }.include?(final.last)
        else final.push(part)
      end
    end
    
    replace(final.empty? ? '.' : File.join(*final))
  end
  
  def cleanpath
    dup.cleanpath!
  end
  
  def ctime
    File.ctime(self)
  end
  
  def descend
    if root?
      yield ROOT
    else
      parts = to_a
      1.upto(parts.length) do |i|
        yield File.join(parts[0, i]).to_path
      end
    end
  end
  
  def directory?
    File.directory?(self)
  end
  
  def dirname
    File.dirname(self).to_path
  end
  
  def each_line(sep = $/, &blk)
    File.foreach(self, sep, &blk)
  end
  
  def entries
    Dir.entries(self).map! {|entry| entry.to_path }
  end
  
  def executable?
    File.executable?(self)
  end
  
  def executable_real?
    File.executable_real?(self)
  end
  
  def exists?
    File.exists?(self)
  end
  
  def expand_path(from = nil)
    File.expand_path(self, from).to_path
  end
  
  def extname
    File.extname(self)
  end
  
  def file?
    File.file?(self)
  end
  
  def find(&blk)
    Find.find(self, &blk)
  end
  
  def fnmatch?(pattern, flags = 0)
    File.fnmatch(pattern, self, flags)
  end
  
  def ftype
    File.ftype(self)
  end
  
  def grpowned?
    File.grpowned?(self)
  end
  
  def join(*paths)
    File.join(self, *paths).to_path
  end
  
  def lchmod(mode)
    File.lchmod(mode, self)
  end
  
  def lchown(owner, group)
    File.lchown(owner, group, self)
  end
  
  def relative?
    !absolute?
  end
  
  def root?
    self =~ %r{^/+$}
  end
  
  def to_a
    array = split(File::SEPARATOR)
    array.delete('')
    array.insert(0, ROOT) if absolute?
    array
  end
  
  def unlink
    File.unlink(self)
  end
  
  alias delete  unlink
  alias exist?  exists?
  alias fnmatch fnmatch?
end

class String
  def to_path
    Pathname.new(self)
  end
end