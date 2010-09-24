use Smart::Comments;
use Test::More 'no_plan';

close *STDERR;
my $STDERR = q{};
open *STDERR, '>', \$STDERR;

my $line = __LINE__+1;
### [<here>]
my $file = quotemeta(__FILE__);

like $STDERR, qr/\["$file", line $line\]/;
