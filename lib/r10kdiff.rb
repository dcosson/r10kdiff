require 'optparse'
require 'set'

module R10kDiff
  class PuppetfileDSL
    def initialize(puppetfile_text)
      @forge = 'forge.puppet.com'
      @modules = {}
      eval(puppetfile_text)
    end
    attr_reader :modules

    def forge(name)
      @forge = name
    end

    def mod(name, args={})
      args = {:ref => args} if args.is_a? String
      args[:ref] = "master" unless args[:ref]
      args[:forge] = "https://#{@forge}/#{name}"
      @modules[name] = PuppetModule.new name, args
    end
  end

  class PuppetModule
    def initialize(name, ref:nil, git:nil, forge:nil, tag:nil, commit:nil, branch:nil)
      @name = name
      @ref = ref
      @git = git
      @forge = forge
    end
    attr_reader :name, :ref, :tag, :commit, :branch

    def git?
      !!@git
    end

    def different?(other_module)
      # Note that forge & git r10k modules have different naming convention so
      # we don't need to compare url (forge is user/modulename and git is just
      # modulename with :git attr as the url of the module
      @ref != other_module.ref
    end

    def pretty_version_diff(other_module, include_url)
      basic_compare = "#{ref} -> #{other_module.ref}"

      # special case for github - generate compate url
      if git? && other_module.git? && include_url
        return "#{name} #{git_https}/compare/#{ref}...#{other_module.ref}"

      elsif include_url
        return "#{name} #{basic_compare} (#{web_url})"
      else
        return "#{name} #{basic_compare}"
      end
    end

    def pretty_version(include_url)
      basic_string = "#{name} at #{ref}"
      if include_url
        return "#{basic_string} (#{web_url})"
      else
        return basic_string
      end

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
      return git? ? git_https : @forge
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

    def print_differences(include_url)
      # Print the additions, removals, and changes
      output = []
      puppetfile_changes = false
      if removals.length > 0
        puppetfile_changes = true
        output << "Remove:"
      end
      removals.each do |old|
        output << "    #{old.pretty_version(include_url)}"
      end

      if additions.length > 0
        puppetfile_changes = true
        output << "Add:"
      end
      additions.each do |new|
        output << "    #{new.pretty_version(include_url)}"
      end

      if changes.length > 0
        puppetfile_changes = true
        output << "Change:"
      end
      changes.each do |old, new|
        output << "    #{old.pretty_version_diff(new, include_url)}"
      end

      if !puppetfile_changes
        output << "No changes in Puppetfile"
      end

      output.each { |x| puts x }
    end
  end

  class Commandline
    def self.run
      include_urls = false
      opt_parser = OptionParser.new do |opt|

      opt.banner = <<-EOF
Usage: r10kdiff [previous-ref] [current-ref]

Run from a git repository containing a Puppetfile.

    previous-ref and current-ref are the git refs to compare
        (optional, default to origin/BRANCH and BRANCH
         where BRANCH is the currently checked-out git branch name)

EOF
        opt.on("-h", "--help", "show help dialogue") do
          puts opt_parser
          exit
        end
        opt.on("-u", "--urls", "Include urls and github compare links in output") do
          include_urls = true
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
      oldfile_raw = PuppetfileDSL.new(`git show #{oldref}:Puppetfile`)
      newfile_raw = PuppetfileDSL.new(`git --no-pager show #{newref}:Puppetfile`)
      PuppetfileDiff.new(oldfile_raw, newfile_raw).print_differences(include_urls)
    end
  end
end
