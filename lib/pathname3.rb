require 'find'

class Pathname < String
  VERSION     = '1.0.0'
  ROOT        = Pathname.new('/')
  SYMLOOP_MAX = 8
  
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
  
  def children
    entries[2..-1]
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
    SYMLOOP_MAX.times { path = path.readlink }
    raise Errno::ELOOP, self
  rescue Errno::EINVAL
    path.expand_path
  end
  
  def relative?
    !absolute?
  end
  
  def relative_path_from(base)
    
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
end

class Pathname
  def atime; File.atime(self); end
  def ctime; File.ctime(self); end
  def ftype; File.ftype(self); end
  def lstat; File.lstat(self); end
  def mtime; File.mtime(self); end
end

class Pathname
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
end

class Pathname
  def each_line(sep = $/, &blk); IO.foreach(self, sep, &blk); end
  def open(mode, &blk);          IO.open(self, mode, &blk);   end
  def read(len = nil, off = 0);  IO.read(self, len, off);     end
  def readlines(sep = $/);       IO.readlines(self, sep);     end
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