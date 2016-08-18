use utf8;
package FixMyStreet::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("users");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "users_id_seq",
  },
  "email",
  { data_type => "text", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "phone",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "flagged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "from_body",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "facebook_id",
  { data_type => "bigint", is_nullable => 1 },
  "twitter_id",
  { data_type => "bigint", is_nullable => 1 },
  "is_superuser",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "area_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("users_email_key", ["email"]);
__PACKAGE__->add_unique_constraint("users_facebook_id_key", ["facebook_id"]);
__PACKAGE__->add_unique_constraint("users_twitter_id_key", ["twitter_id"]);
__PACKAGE__->has_many(
  "admin_logs",
  "FixMyStreet::DB::Result::AdminLog",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "alerts",
  "FixMyStreet::DB::Result::Alert",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "bodies",
  "FixMyStreet::DB::Result::Body",
  { "foreign.comment_user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "comments",
  "FixMyStreet::DB::Result::Comment",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "from_body",
  "FixMyStreet::DB::Result::Body",
  { id => "from_body" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "problems",
  "FixMyStreet::DB::Result::Problem",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_body_permissions",
  "FixMyStreet::DB::Result::UserBodyPermission",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "user_planned_reports",
  "FixMyStreet::DB::Result::UserPlannedReport",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2016-08-03 13:52:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SX8BS91mWHoOm2oWdNth1w

use Moo;
use mySociety::EmailUtil;

__PACKAGE__->many_to_many( planned_reports => 'user_planned_reports', 'report' );

__PACKAGE__->add_columns(
    "password" => {
        encode_column => 1,
        encode_class => 'Crypt::Eksblowfish::Bcrypt',
        encode_args => { cost => 8 },
        encode_check_method => 'check_password',
    },
);

sub latest_anonymity {
    my $self = shift;
    my $p = $self->problems->search(undef, { order_by => { -desc => 'id' } } )->first;
    my $c = $self->comments->search(undef, { order_by => { -desc => 'id' } } )->first;
    my $p_created = $p ? $p->created->epoch : 0;
    my $c_created = $c ? $c->created->epoch : 0;
    my $obj = $p_created >= $c_created ? $p : $c;
    return $obj ? $obj->anonymous : 0;
}

=head2 check_for_errors

    $error_hashref = $user->check_for_errors();

Look at all the fields and return a hashref with all errors found, keyed on the
field name. This is intended to be passed back to the form to display the
errors.

TODO - ideally we'd pass back error codes which would be humanised in the
templates (eg: 'missing','email_not_valid', etc).

=cut

sub check_for_errors {
    my $self = shift;

    my %errors = ();

    if ( !$self->name || $self->name !~ m/\S/ ) {
        $errors{name} = _('Please enter your name');
    }

    if ( $self->email !~ /\S/ ) {
        $errors{email} = _('Please enter your email');
    }
    elsif ( !mySociety::EmailUtil::is_valid_email( $self->email ) ) {
        $errors{email} = _('Please enter a valid email');
    }

    return \%errors;
}

=head2 answered_ever_reported

Check if the user has ever answered a questionnaire.

=cut

sub answered_ever_reported {
    my $self = shift;

    my $has_answered =
      $self->result_source->schema->resultset('Questionnaire')->search(
        {
            ever_reported => { not => undef },
            problem_id => { -in =>
                $self->problems->get_column('id')->as_query },
        }
      );

    return $has_answered->count > 0;
}

=head2 alert_for_problem

Returns whether the user is already subscribed to an
alert for the problem ID provided.

=cut

sub alert_for_problem {
    my ( $self, $id ) = @_;

    return $self->alerts->find( {
        alert_type => 'new_updates',
        parameter  => $id,
    } );
}

sub body {
    my $self = shift;
    return '' unless $self->from_body;
    return $self->from_body->name;
}

=head2 belongs_to_body

    $belongs_to_body = $user->belongs_to_body( $bodies );

Returns true if the user belongs to the comma seperated list of body ids passed in

=cut

sub belongs_to_body {
    my $self = shift;
    my $bodies = shift;

    return 0 unless $bodies && $self->from_body;

    my %bodies = map { $_ => 1 } split ',', $bodies;

    return 1 if $bodies{ $self->from_body->id };
    return 0;
}

=head2 split_name

    $name = $user->split_name;
    printf( 'Welcome %s %s', $name->{first}, $name->{last} );

Returns a hashref with first and last keys with first name(s) and last name.
NB: the spliting algorithm is extremely basic.

=cut

sub split_name {
    my $self = shift;

    my ($first, $last) = $self->name =~ /^(\S*)(?: (.*))?$/;

    return { first => $first || '', last => $last || '' };
}

sub has_permission_to {
    my ($self, $permission_type, $body_id) = @_;

    return 1 if $self->is_superuser;

    return unless $self->belongs_to_body($body_id);

    my $permission = $self->user_body_permissions->find({ 
            permission_type => $permission_type,
            body_id => $self->from_body->id,
        });
    return $permission ? 1 : undef;
}

sub contributing_as {
    my ($self, $other, $c, $bodies) = @_;
    $bodies = join(',', keys %$bodies) if ref $bodies eq 'HASH';
    $c->log->error("Bad data $bodies passed to contributing_as") if ref $bodies;
    my $form_as = $c->get_param('form_as') || '';
    return 1 if $form_as eq $other && $self->has_permission_to("contribute_as_$other", $bodies);
}

sub adopt {
    my ($self, $other) = @_;

    return if $self->id == $other->id;

    # Move most things from $other to $self
    foreach (qw(Problem Comment Alert AdminLog )) {
        $self->result_source->schema->resultset($_)
            ->search({ user_id => $other->id })
            ->update({ user_id => $self->id });
    }

    # It's possible the user permissions for the other user exist, so
    # try updating, and then delete anyway.
    foreach ($self->result_source->schema->resultset("UserBodyPermission")
                ->search({ user_id => $other->id })->all) {
        eval {
            $_->update({ user_id => $self->id });
        };
        $_->delete if $@;
    }

    # Delete the now empty user
    $other->delete;
}

# Planned reports

# Override the default auto-created function as we only want one live entry per user
around add_to_planned_reports => sub {
    my ( $orig, $self ) = ( shift, shift );
    my ( $report_col ) = @_;
    my $existing = $self->user_planned_reports->search_rs({ report_id => $report_col->{id}, removed => undef })->first;
    return $existing if $existing;
    return $self->$orig(@_);
};

# Override the default auto-created function as we don't want to ever delete anything
around remove_from_planned_reports => sub {
    my ($orig, $self, $report) = @_;
    $self->user_planned_reports
        ->search_rs({ report_id => $report->id, removed => undef })
        ->update({ removed => \'current_timestamp' });
};

sub active_planned_reports {
    my $self = shift;
    $self->planned_reports->search({ removed => undef });
}

sub is_planned_report {
    my ($self, $problem) = @_;
    return $self->active_planned_reports->find({ id => $problem->id });
}

1;
