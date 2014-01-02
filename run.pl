#!/usr/bin/perl
use warnings;
use strict;

sub git {
    print join(' ', 'git', @_), "\n";
    system('git', @_);
    return !$?;
}

my $queuefile = $ARGV[0];
my $base = $ARGV[1];
my $build = $ARGV[2];

# Which commits are already merged into the branch we're building?
my @merged = split '\n', 
    `git log --first-parent --reverse --merges --format='%H %P' '$base'..'$build'`;

# Which commits do we want to end up in our branch?
open QUEUE, "<$queuefile" or die "$!";
my @queue = <QUEUE>;
close QUEUE;

my %branches = ();
for (@queue) {
    chomp;
    my $showref = `git show-ref '$_'`;
    if ($showref !~ /([0-9a-f]{40}) .+$/) {
        die "invalid branch $_.";
    } else {
        $branches{$1} = [] unless ($branches{$1});
        push @{$branches{$1}}, $_;
    }
}

# Find the most recent commit to our branch that is not
# contaminiated by a merge that we don't want
my $last_merged = $base;
for my $i (0..$#merged) {
    my @h = ($merged[$i] =~ /[a-f0-9]{40}/g); 
    if (exists($branches{$h[2]})) {
        for my $x (@{$branches{$h[2]}}) {
            @queue = grep {$_ ne $x} @queue;    
        }
        $last_merged = $h[0];
        next;
    }
    $merged[$i..$#merged] = ();
    last;
}

# Reset the branch we're building to our starting point
git('checkout', $build) or die "checkout failed";
git('reset', '--soft', $last_merged) or die "soft reset failed";

# Finally, for each branch that we want, see if it merges cleanly.
for (@queue) {
    git('reset', '--hard') or die "hard reset failed";
    #git('clean', '--force') or die "clean failed";

    if (!git('merge', '--no-ff', '-m', "Automerge $_", $_)) {
        if (!`git rerere remaining`) {
            # rerere found a resolution, go with it
            git('add', split("\n", `git diff --name-only --diff-filter=U`));
            git('commit', '-m', "Automerge $_ with recorded conflict");
        } else {
            # merge failed with no resolution, too bad, so sad.
            git('reset', '--hard');
            next;
        }
    }

    if (-f 'Makefile' && system('make')) {
        # The merge was clean, but the build is still broken.  Excise
        # this branch for now, and try to keep going.
        git('reset', '--soft', 'HEAD^')
    }
}
