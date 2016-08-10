use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my/planned');
is $mech->uri->path, '/auth', "got sent to the sign in page";

my ($problem) = $mech->create_problems_for_body(1, 1234, 'Test Title');

my $user = $mech->log_in_ok( 'test@example.com' );
$mech->get_ok('/my/planned');
$mech->content_lacks('Test Title');

$user->add_to_planned_reports($problem);
$mech->get_ok('/my/planned');
$mech->content_contains('Test Title');

$user->remove_from_planned_reports($problem);
$mech->get_ok('/my/planned');
$mech->content_lacks('Test Title');

$user->add_to_planned_reports($problem);
$mech->get_ok('/my/planned');
$mech->content_contains('Test Title');

done_testing();

END {
    $mech->delete_user($user);
}
