use utf8;
package Pluton::Schema::Result::PathAuthorization;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Pluton::Schema::Result::PathAuthorization

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<path_authorizations>

=cut

__PACKAGE__->table("path_authorizations");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'path_authorizations_id_seq'

=head2 created

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 updated

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 role

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 path

  data_type: 'varchar'
  is_nullable: 0
  size: 250

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "path_authorizations_id_seq",
  },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "updated",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "role",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "path",
  { data_type => "varchar", is_nullable => 0, size => 250 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<path_authorizations_role_path_key>

=over 4

=item * L</role>

=item * L</path>

=back

=cut

__PACKAGE__->add_unique_constraint("path_authorizations_role_path_key", ["role", "path"]);

=head1 RELATIONS

=head2 role

Type: belongs_to

Related object: L<Pluton::Schema::Result::Role>

=cut

__PACKAGE__->belongs_to(
  "role",
  "Pluton::Schema::Result::Role",
  { id => "role" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2017-11-04 11:12:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KUdvd5s6/nBhyz348P9iYg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
