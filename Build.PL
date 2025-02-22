#!/usr/bin/perl

use strict;
use warnings;

use Config;
use File::Spec;

my %prereqs = qw(
);
my %recommends = qw(

);

my $sudo    = grep { $_ eq '--sudo' } @ARGV;
my $gui     = grep { $_ eq '--gui' } @ARGV;
my $xs_only = grep { $_ eq '--xs' }  @ARGV;
if ($gui) {
    %prereqs = qw(
    Class::Accessor                 0
    Wx                              0.9918
    Socket                          2.016
    );
    %recommends = qw(
    Growl::GNTP                     0.15
    Wx::GLCanvas                    0
    OpenGL                          0
    LWP::UserAgent                  0
    Net::Bonjour                    0
    );
    if ($^O eq 'MSWin32') {
    }
} elsif ($xs_only) {
    %prereqs = %recommends = ();
}

my @missing_prereqs = ();
if ($ENV{SLIC3R_NO_AUTO}) {
    foreach my $module (sort keys %prereqs) {
        my $version = $prereqs{$module};
        next if eval "use $module $version; 1";
        push @missing_prereqs, $module if exists $prereqs{$module};
        print "Missing prerequisite $module $version\n";
    }
    foreach my $module (sort keys %recommends) {
        my $version = $recommends{$module};
        next if eval "use $module $version; 1";
        print "Missing optional $module $version\n";
    }
} else {
    my @try = (
        $ENV{CPANM} // (),
        File::Spec->catfile($Config{sitebin}, 'cpanm'),
        File::Spec->catfile($Config{installscript}, 'cpanm'),
    );
    
    my $cpanm;
    foreach my $path (@try) {
        if (-e $path) {  # don't use -x because it fails on Windows
            $cpanm = $path;
            last;
        }
    }
    if (!$cpanm) {
        if ($^O =~ /^(?:darwin|linux)$/ && system(qw(which cpanm)) == 0) {
            $cpanm = 'cpanm';
        }
    }
    die <<'EOF'
cpanm was not found. Please install it before running this script.

There are several ways to install cpanm, try one of these:

    apt-get install cpanminus
    curl -L http://cpanmin.us | perl - --sudo App::cpanminus
    cpan App::cpanminus

If it is installed in a non-standard location you can do:
    
    CPANM=/path/to/cpanm perl Build.PL

EOF
        if !$cpanm;
    my @cpanm_args = ();
    push @cpanm_args, "--sudo" if $sudo;
    
    # install local::lib without --local-lib otherwise it's not usable afterwards
    if (!eval "use local::lib qw(local-lib); 1") {
        my $res = system $cpanm, @cpanm_args, 'local::lib';
        warn "Warning: local::lib is required. You might need to run the `cpanm --sudo local::lib` command in order to install it.\n"
            if $res != 0;
    }
    
    push @cpanm_args, ('--local-lib', 'local-lib');
    
    # make sure our cpanm is updated (old ones don't support the ~ syntax)
    system $cpanm, @cpanm_args, 'App::cpanminus';
    
    my %modules = (%prereqs, %recommends);
    foreach my $module (sort keys %modules) {
        my $version = $modules{$module};
        my @cmd = ($cpanm, @cpanm_args);
        
        # temporary workaround for upstream bug in test
        push @cmd, '--notest'
            if $module =~ /^(?:OpenGL|Math::PlanePath|Test::Harness|IO::Scalar)$/;
        
        push @cmd, "$module~$version";
        my $res = system @cmd;
        if ($res != 0) {
            if (exists $prereqs{$module}) {
                push @missing_prereqs, $module;
            } else {
                printf "Don't worry, this module is optional.\n";
            }
        }
    }
}

if (@missing_prereqs) {
    printf "The following prerequisites failed to install: %s\n", join(', ', @missing_prereqs);
    exit 1;
}

__END__
