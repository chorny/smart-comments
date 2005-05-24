use Smart::Comments;
use Test::More 'no_plan';

close *STDERR;
my $STDERR = q{};
open *STDERR, '>', \$STDERR;

my $count = 0;

LABEL:

while ($count < 25) {    ### Simple while loop:===[%]   done (%)
    $count++;
}

like $STDERR, qr/Simple while loop:\[0\]           done \(0\)\r/
                                            => 'First iteration';

like $STDERR, qr/Simple while loop:=\[3\]          done \(3\)\r/ 
                                            => 'Second iteration';

like $STDERR, qr/Simple while loop:==\[7\]         done \(7\)\r/ 
                                            => 'Third iteration';

like $STDERR, qr/Simple while loop:===\[15\]      done \(15\)\r/ 
                                            => 'Fourth iteration';

like $STDERR, qr/Simple while loop:====\[24\]     done \(24\)/ 
                                            => 'Fifth iteration';
