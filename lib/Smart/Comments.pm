package Smart::Comments;

use 5.006;
our $VERSION = '0.01';

use strict;
use List::Util qw(sum);
use Filter::Simple;

our $maxwidth         = 79;     # Maximum width of display
our $showwidth        = 40;     # How wide to make the indicator
our $showstarttime    = 6;      # How long before showing time-remaining estimate
our $showmaxtime      = 10;     # Don't start estimate if less than this to go
our $whilerate        = 30;     # Controls the rate at which while indicator grows
our $minfillwidth     = 5;      # Fill area must be at least this wide
our $average_over     = 5;      # Number of time-remaining estimates to average
our $minfillreps      = 2;      # Minimum size of a fill and fill cap indicator
our $forupdatequantum = 0.01;   # Only update every 1% of elapsed distance

my $require = qr/require|ensure|assert|insist/;
my $check   = qr/check|verify|confirm/;

my $hws = qr/[^\S\n]/;

FILTER {
    shift;
s{ ^ $hws* ( for(?:each)? \s* (?:my)? \s* (?:\$ [^\W\d]\w*)? \s* ) \( ([^;\n]*?) \) \s* \{
            [ \t]* \#{3} \s (.*) \s* $
     }
     { decode_for($1, $2, $3) }xgem;

    s{ ^ $hws* ( (?:while|until) \s* \( .*? \) \s* ) \{
            [ \t]* \#{3} \s (.*) \s* $
     }
     { decode_while($1, $2) }xgem;

    s{ ^ $hws* ( for \s* \( .*? ; .*? ; .*? \) \s* ) \{
            [ \t]* \#{3} \s (.*) \s* $
     }
     { decode_while($1, $2) }xgem;

    s{ ^ $hws* \#{3} [ \t] $require : \s* (.*) $ }
     { decode_assert($1,"fatal") }gemx;

    s{ ^ $hws* \#{3} [ \t] $check : \s* (.*) $ }
     { decode_assert($1) }gemx;

    s{ ^ $hws* \#{3} [ \t]+ (\$ [\w:]* \w) [ \t]* $ }
     {Smart::Comments::Dump(pref=>q{$1:},var=>[$1]);}gmx;

    s{ ^ $hws* \#{3} [ \t] (.+ :) [ \t]* (\$ [\w:]* \w) [ \t]* $ }
     {Smart::Comments::Dump(pref=>q{$1},var=>[$2]);}gmx;

    s{ ^ $hws* \#{3} [ \t]+ ([\@%] [\w:]* \w) [ \t]* $ }
     {Smart::Comments::Dump(pref=>q{$1:},var=>[\\$1]);}gmx;

    s{ ^ $hws* \#{3} [ \t]+ (.+ :) [ \t]* ([\@%] [\w:]* \w) [ \t]* $ }
     {Smart::Comments::Dump(pref=>q{$1},var=>[\\$2]);}gmx;

    s{ ^ $hws* \#{3} [ \t]+ (.+ :) (.+) }
     {Smart::Comments::Dump(pref=>q{$1},var=>[$2]);}gmx;

    s{ ^ $hws* \#{3} [ \t]+ (\S.+) }
     {Smart::Comments::Dump(pref=>q{$1:},var=>eval q{[$1]});}gmx;

    s{ ^ $hws* \#{3} [ \t]+ $ }
     {warn qq{\n};}gmx;
};

sub decode_assert {
    my ($assertion, $fatal) = @_;
    $fatal = $fatal ? 'die "\n"' : 'warn "\n"';
    my $dump = 'Smart::Comments::Dump';
    use Text::Balanced qw(extract_variable extract_multiple);
    my @vars = map {
            /^$hws*[%\@]/
          ? "$dump(pref=>q{    $_ was:},var=>[\\$_], nonl=>1);"
          : "$dump(pref=>q{    $_ was:},var=>[$_],nonl=>1);"
    } extract_multiple($assertion, [ \&extract_variable ], undef, 1);
    return
qq{unless($assertion){warn "\\n", '### $assertion was not true';@vars; $fatal}};
}

my $counter = 0;

sub decode_for {
    my ($for, $range, $mesg) = @_;
    $counter++;
    return
      "my \$not_first__$counter;$for (my \@SmartComments__range__$counter =
    $range ) { Smart::Comments::for_progress(qq{$mesg}, \$not_first__$counter, \\\@SmartComments__range__$counter);";
}

sub decode_while {
    my ($while, $mesg) = @_;
    $counter++;
    return
"my \$not_first__$counter;$while { Smart::Comments::while_progress(qq{$mesg}, \\\$not_first__$counter);";
}

sub desc_time {
    my ($seconds) = @_;
    my $hours = int($seconds / 3600);
    $seconds -= 3600 * $hours;
    my $minutes = int($seconds / 60);
    $seconds -= 60 * $minutes;
    my $remaining;
    if ($hours) {
        $remaining =
          $minutes < 5
          ? "about $hours hour" . ($hours == 1 ? "" : "s")
          : $minutes < 25 ? "less than $hours.5 hours"
          : $minutes < 35 ? "about $hours.5 hours"
          : $minutes < 55 ? "less than " . ($hours + 1) . " hours"
          : "about " . ($hours + 1) . " hours";
    }
    elsif ($minutes) {
        $remaining = "about $minutes minutes";
        chop $remaining if $minutes == 1;
    }
    elsif ($seconds > 10) {
        $seconds   = int(($seconds + 5) / 10);
        $remaining = "about ${seconds}0 seconds";
    }
    else {
        $remaining = "less than 10 seconds";
    }
    return $remaining;
}

my %started;
my %moving;

sub moving_average {
    my ($context, $next) = @_;
    my $moving = $moving{$context} ||= [];
    push @$moving, $next;
    if (@$moving >= $average_over) {
        splice @$moving, 0, $#$moving - $average_over;
    }
    return sum(@$moving) / @$moving;
}

our @progress_pats = (
    ### left     fill                     leader                  right
    qr{^(\s*.*?) (?>(\S)\2{$minfillreps,}) (\S+)\s{$minfillreps,} (\S.+)}x,
    qr{^(\s*.*?) (?>(\S)\2{$minfillreps,}) ()   \s{$minfillreps,} (\S.+)}x,
    qr{^(\s*.*?) (?>(\S)\2{$minfillreps,}) (\S*)                  (?=\s*$)}x,
    qr{^(\s*.*?) ()                        ()                     () \s*$ }x,
);

sub prog_pat {
    for my $pat (@progress_pats) {
        $_[0] =~ $pat or next;
        return ($1, $2 || "", $3 || "", $4 || "");
    }
    return;
}

my (%count, %max, %last_elapsed, %last_fraction, %showing);

sub for_progress {
    my ($mesg, $not_first, $data) = @_;
    my ($at, $max, $elapsed, $remaining, $fraction);
    if ($not_first) {
        $at       = ++$count{$data};
        $max      = $max{$data};
        $elapsed  = time - $started{$data};
        $fraction = $max > 0 ? $at / $max : 1;
        my $motion = $fraction - $last_fraction{$data};
        return
          unless $not_first < 0 || $at == $max || $motion > $forupdatequantum;
        $remaining =
          moving_average $data, $fraction
          ? $elapsed / $fraction - $elapsed
          : 0;
    }
    else {
        $at  = $count{$data} = 0;
        $max = $max{$data}   = $#$data;
        $started{$data} = time;
        $elapsed        = 0;
        $fraction       = 0;
        $_[1]           = 1;      # $not_first
    }
    $last_fraction{$data} = $fraction;

    if (my ($left, $fill, $leader, $right) = prog_pat($mesg)) {
        s/%/int(100*$fraction).'%'/ge for ($left, $leader, $right);
        my $fillwidth = $showwidth - length($left) - length($right);
        $fillwidth = $minfillwidth if $fillwidth < $minfillwidth;
        my $leaderwidth = length($leader);
        print STDERR "\r", " " x $maxwidth, "\r", $left,
          sprintf("%-${fillwidth}s",
              $at == $max
            ? $fill x $fillwidth
            : $fill x ($fillwidth * $fraction - $leaderwidth) . $leader),
          $right;

        if (   $elapsed >= $showstarttime
            && $at < $max
            && ($showing{$data} || $remaining && $remaining >= $showmaxtime))
        {
            print STDERR "  (", desc_time($remaining), " remaining)";
            $showing{$data} = 1;
        }
        print STDERR "\n" if $at >= $max;
    }
}

my %shown;
my $last_length = -1;

sub while_progress {
    my ($mesg, $not_first_ref) = @_;
    my $at;
    if ($$not_first_ref) {
        $at = ++$count{$not_first_ref};
    }
    else {
        $at = $count{$not_first_ref} = 0;
        $$not_first_ref = 1;
    }

    if (my ($left, $fill, $leader, $right) = prog_pat($mesg)) {
        s/%/$at/ge for ($left, $leader, $right);
        my $fillwidth = $showwidth - length($left) - length($right);
        $fillwidth = $minfillwidth if $fillwidth < $minfillwidth;
        my $leaderwidth = length($leader);
        my $length      =
          int(($fillwidth - $leaderwidth) *
              (1 - $whilerate / ($whilerate + $at)));
        return if $last_length == $length;
        $last_length = $length;
        print STDERR "\r", " " x $maxwidth, "\r", $left,
          sprintf("%-${fillwidth}s", $fill x $length . $leader), $right;
    }
}

sub Assert {
    my %arg = @_;
    return unless $arg{pass};
}

use Data::Dumper 'Dumper';

sub Dump {
    my %args = @_;
    my ($pref, $varref, $nonl) = @args{qw(pref var nonl)};
    my $nl = $nonl ? "" : "\n";
    if ($pref && !defined $varref) {
        $pref =~ s/:$//;
        warn "$nl### $pref\n";
        return;
    }
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Indent    = 2;
    my $dumped = Dumper $varref;
    $dumped =~ s/\$VAR1 = \[\n//;
    $dumped =~ s/\s*\];\s*$//;
    $dumped =~ s/^(\s*)//;
    my $indent = length $1;
    my $outdent = " " x (length($pref) + 1);
    $dumped =~ s/^[ ]{$indent}([ ]*)/### $outdent$1/gm;
    warn "$nl### $pref $dumped\n$nl";
}

1;
__END__

=head1 NAME

Smart::Comments - Comments that come to life

=head1 VERSION

This document describes version 0.01 of Smart::Comments, released
September 28, 2004.

=head1 SYNOPSIS

    use Smart::Comments;
    my $x = 1; my $y = 2;
    sub is_odd { $_[0] % 2 }

    ### require: $x > $y
    ### require: is_odd($y)

    for (my $j=500; $j>0; $j--) {   ### Compiling===[%]  done
        select undef, undef, undef, 0.01;
    }

=head1 DESCRIPTION

This module filters your source code, turning any comments beginning with
C<###> into code that interacts with the rest of the program.

To remove this effect, simple remove the C<use Smart::Comments> line, and
the original code will run with no speed penalty at all.  You may also turn
off the filtering lexically, using C<no Smart::Comments>.

Here are some more examples of how this module works:

    while (<>) {                    ### Loading $_
        sleep 1;
    }

    my $i = 10;
    while ($i-- > 0) {              ### Preparing----->
        sleep 1;
    }
    ### i now: $i

    for my $j (1..500) {            ### Compiling===[%]  done
        select undef, undef, undef, 0.01;
    }

    %foo = ( a=>{foo=>'bar'}, b=>[1..5] );
    ### %foo

    for (1..25) {                   ### Loading...  done
        sleep 1;
    }

    ### check: keys(%foo) == 2
    ### require: keys(%foo) == 3

=head1 CAVEATS

Currently, there are no meaningful tests and documentation for this module.
Contributions will be very much appreciated.

=head1 TODO

Fix line numbering problem (i.e. last message in the example above).

Add line numbers to non-progress-bar reports.

=head1 AUTHOR

Damian Conway (damian@conway.org)

=head1 MAINTAINERS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>,
Brian Ingerson E<lt>INGY@cpan.orgE<gt>.

=head1 COPYRIGHT

   Copyright (c) 2004, Damian Conway. All Rights Reserved.
 This module is free software. It may be used, redistributed
     and/or modified under the same terms as Perl itself.
