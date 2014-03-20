Gem::Specification.new do |s|
  s.name        = 'r10kdiff'
  s.version     = '0.0.2'
  s.date        = '2014-03-20'
  s.summary     = "Compare r10k Puppetfiles"
  s.description = "A small script for comparing r10k Puppetfiles between different git refs. It's helpful for a development workflow with puppet r10k and Github as the output is slightly nicer than 'git diff' and it can generate github compare links for the full changesets represented by a change to a Puppetfile."
  s.authors     = ["Danny Cosson"]
  s.email       = 'cosson@venmo.com'
  s.executables << 'r10kdiff' 
  s.files       = [ "lib/r10kdiff.rb" ]
  s.homepage    = 'https://github.com/dcosson/r10kdiff'
  s.license     = 'MIT'
end
