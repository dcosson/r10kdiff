r10kdiff
=========

A small script for comparing r10k Puppetfiles between different git refs.

It's helpful for a development workflow with puppet r10k and Github as the output is slightly nicer than 'git diff' and it can generate github compare links for the full changesets represented by a change to a Puppetfile.

## Usage

    $ r10kdiff -h
    Usage: r10kdiff [previous-ref] [current-ref]

    Run from a git repository containing a Puppetfile.

        previous-ref and current-ref are the git refs to compare
            (optional, default to origin/BRANCH and BRANCH
             where BRANCH is the currently checked-out git branch name)

        -h, --help                       show help dialogue
        -u, --urls                       Include urls and github compare links in output

See what's different between development and production

    $ r10kdiff origin/development origin/production
    Remove:
        puppetlabs/somedevthing at 0.2.1
    Add:
        dashboard at 0.1.0
    Change:
        mysql 0.1.0 -> 0.2.0
        python 0.1.0 -> 0.1.1

Generate a diff with urls. Useful for e.g. including in a Pull Request so team members can easily review changes that will go out when the new Puppetfile is deployed.

In this example if "development" branch is checked out, the following is the same as `r10kdiff --urls origin/development development`

    $ r10kdiff --urls
    Add:
        foobar at 0.4.0 (https://github.com/dcosson/puppet-foobar)
    Change:
        blerg https://github.com/dcosson/puppet-blerg/compare/0.1.1...0.1.2
