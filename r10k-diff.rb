#!/usr/bin/env ruby -w

require 'optparse'
require 'set'

class Puppetfile
  def initialize(puppetfile_text)
    @forge = 'forge.puppetlabs.com'
    @modules = {}
    eval(puppetfile_text)
  end
  attr_reader :modules

  def forge(name)
    @forge = name
  end

  def mod(name, args={})
    args = {:ref => args} if args.is_a? String
    args = {:ref => "master"} unless args && args.has_key?(:ref)
    args[:forge] = "https://#{@forge}/#{name}" unless args[:git]
    @modules[name] = PuppetModule.new name, args
  end
end

class PuppetModule
  def initialize(name, ref:nil, git:nil, forge:nil)
    @name = name
    @ref = ref
    @git = git
    @forge = forge
  end
  attr_reader :name, :ref, :git

  def different?(other_module)
    @ref != other_module.ref
  end

  def git_https
    if @git.start_with? "https://"
      return @git
    elsif @git.start_with? "git://"
      return @git.gsub(/^git:/, "https:")
    elsif @git.start_with? "git@"
      return @git.gsub(":", "/").gsub(/^git@/, "https://").gsub(/.git$/, "")
    end
  end

  def web_url
    return @forge ? @forge : git_https
  end
end

class PuppetfileDiff
  # Represents the difference between the puppetfile from one commit to another
  def initialize(oldfile, newfile)
    @oldfile = oldfile
    @newfile = newfile
  end

  def changes
    changed_modules = []
    modules_in_common = Set.new(@oldfile.modules.keys).intersection Set.new(@newfile.modules.keys)
    modules_in_common.each do |name|
      new_module = @newfile.modules[name]
      old_module = @oldfile.modules[name]
      changed_modules << [old_module, new_module] if new_module.different? old_module
    end
    changed_modules
  end

  def additions
    additions = []
    @newfile.modules.each do |name, new_module|
      additions << new_module unless @oldfile.modules[name]
    end
    additions
  end

  def removals
    removals = []
    @oldfile.modules.each do |name, old_module|
      removals << old_module unless @newfile.modules[name]
    end
    removals
  end

  def print_puppetfile_changes
    output = []
    puppetfile_changes = false
    if removals.length > 0
      puppetfile_changes = true
      output << "Remove:"
    end
    removals.each do |old|
      output << "    #{old.name} #{old.web_url}"
    end

    if additions.length > 0
      puppetfile_changes = true
      output << "Add:"
    end
    additions.each do |new|
      output << "    #{new.name} #{new.web_url}"
    end

    if changes.length > 0
      puppetfile_changes = true
      output << "Change:"
    end
    changes.each do |old, new|
      if new.git
        output << "    #{new.name} #{old.git_https}/compare/#{old.ref}...#{new.ref}"
      else
        output << "    #{new.name} (#{new.web_url}) change #{old.ref} -> #{new.ref}"
      end
    end

    if !puppetfile_changes
      output << "No changes in Puppetfile"
    end

    print output.join('\n')
  end
end


if __FILE__ == $0
  opt_parser = OptionParser.new do |opt|
    opt.banner = "Usage: r10k-diff [previous-ref] [current-ref]"
    opt.on("-h", "--help", "help") do
      puts opt_parser
      exit
    end
  end
  opt_parser.parse!

  if ARGV.length >= 2
    oldref = ARGV[0]
    newref = ARGV[1]
  else  # default to checked-out branch & its corresponding branch on origin
    branch_name = File.basename `git symbolic-ref HEAD`.chomp
    oldref = "origin/#{branch_name}"
    newref = branch_name
  end
  oldfile_raw = Puppetfile.new(`git show #{oldref}:Puppetfile`)
  newfile_raw = Puppetfile.new(`git --no-pager show #{newref}:Puppetfile`)
  PuppetfileDiff.new(oldfile_raw, newfile_raw).print_puppetfile_changes
end
