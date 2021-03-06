package Pluton::SystemUser;
use Modern::Perl;
use Moose;
use namespace::autoclean;
use Main::JSON::Validator;

extends 'Pluton::SystemUser::Command';

our $__system_user_credentials_schema = {
    required   => [qw(username password)],
    properties => {
        username => { type => 'string', pattern => '^\w+$', minLength => 1, maxLength => 32 },
        password => { type => 'string', pattern => '^[^\n^\r.]+$', minLength => 1, maxLength => 70 },
    }
};

sub __validate_credentials {
    my ($self, $params) = @_;
    my $validator = Main::JSON::Validator->new;
    $validator->schema($__system_user_credentials_schema);

    return $validator->validate($params);
}

sub add {
    my ($self, $params) = @_;
    my $c = $self->c;

    my @errors = $self->__validate_credentials($params);
    if ( $errors[0] ) {
        $self->jsonrpc_error( \@errors );
    }

    if ($c->config->{system_users_blacklist}->{$$params{username}}) {
        $self->jsonrpc_error(
            [   {   path    => '/username',
                    message => 'User is blacklisted',
                }
            ]);

        return;
    }

    my $exist = $c->model('DB::SystemUser')->search({
        owner => $c->user->id,
        username => $$params{username},
    })->next;

    if ( $exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/username',
                    message => 'User exist in your system users list',
                }
            ]);

        return;
    }

    my $run = {
        username => $$params{username},
        password => $$params{password},
        command  => 'whoami',
    };
    my $output = $self->raw($run);

    if (!$output) {
        $self->jsonrpc_error(
            [   {   path    => '/username',
                    message => 'Unexpected error when validating OS user',
                }
            ]);

        return;
    }

    my @_output = split("\n", $output);

    if (scalar( @_output ) < 2 && $_output[2] ne $$params{username}) {
        $self->jsonrpc_error(
            [   {   path    => '/username',
                    message => 'User doesn\'t exist in the OS',
                }
            ]);

        return;
    }

    # Create authinfo2 file and .pluton folder
    $$run{command} = 'mkdir -p ~/.s3ql ~/.pluton/authinfo ~/.pluton/backup ~/.pluton/scripts ~/.pluton/logs && touch ~/.s3ql/authinfo2 && chmod 600 ~/.s3ql/authinfo2';
    $self->raw($run);

    my $pass_encrypted = $self->encrypt_password($$params{password});

    $c->model('DB::SystemUser')->create({
        owner => $c->user->id,
        username => $$params{username},
        password => $pass_encrypted,
    });

    return $self->list;
}

sub rm {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::SystemUser')->search({
        owner => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'User does not exist in your system users list',
                }
            ]);

        return;
    }

    $exist->delete;

    return $self->list;
}

sub list {
    my ($self) = @_;
    my $c = $self->c;

    my @sys_users = $c->model('DB::SystemUser')->search({
        owner => $c->user->id,
    })->all;

    return \@sys_users;
}

sub list_mounts {
    my ($self, $params) = @_;
    my $c = $self->c;

    my @mounts = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        system_user => $$params{system_user},
    })->all;

    return \@mounts;
}

sub s3qlstat {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $output = $self->run({user => $$params{user}, command => "s3qlstat ~/.pluton/backup"});
    my @_output = split("\n", $output);

    return join("\n", @_output);
}

our $__system_user_path_schema = {
    properties => {
        path => { type => 'string', pattern => '^[ \/\-\w]+$', minLength => 1, maxLength => 255, },
    }
};

sub __validate_path {
    my ($self, $params) = @_;
    my $validator = Main::JSON::Validator->new;
    $validator->schema($__system_user_path_schema);

    return $validator->validate($params);
}

# Folders in the system user $HOME
sub folders {
    my ($self, $params) = @_;
    my $c = $self->c;

    my @errors = $self->__validate_path($params);
    if ( $errors[0] ) {
        $self->jsonrpc_error( \@errors );
    }

    my $path = $$params{path};

    if (defined $path) {
        my @parts = split('/', $path);
        foreach my $part (@parts) {
            unless ($part =~ /[ \-\w]/) {
                $self->jsonrpc_error(
                    [   {   path    => '/path',
                            message => 'Invalid path',
                        }
                    ]);
                last;
            }
        }
    }

    $path = $path || '';
    my $output = $self->run({user => $$params{user}, command => "find './$path' -maxdepth 1 -type d -regex '\.[/0-9a-zA-Z_ -]+'"});
    my @_output = split("\n", $output);
    shift @_output;
    shift @_output;
    shift @_output;

    return \@_output;
}

# Folders in mount_root location
sub mount_folders {
    my ($self, $params) = @_;
    my $c = $self->c;
    my $path = $c->config->{mount_root};

    my $output = $self->run({user => $$params{user}, command => "find '$path' -maxdepth 1 -type d -regex '\.[/0-9a-zA-Z_ -]+'"});
    my @_output = split("\n", $output);
    shift @_output;
    shift @_output;
    shift @_output;

    return \@_output;
}

our $__system_user_mounts_schema = {
    required   => [qw(system_user name storage_url fs_passphrase)],
    properties => {
        system_user => { type => 'integer', minimum => 1, maximum => 10000 },
        name => { type => 'string', pattern => '^\w+$', minLength => 1, maxLength => 255 },
        mount_folder => { type => 'string', pattern => '^[ \-\w]+$', minLength => 1, maxLength => 255, },
        storage_url => { type => 'string', format => 'uri', maxLength => 255 },
        backend_login => { type => 'string', pattern => '^[\w\:]+$', minLength => 1, maxLength => 255 },
        backend_password => { type => 'string', pattern => '^[\w+/=@\- ]+$', minLength => 1, maxLength => 255 },
        fs_passphrase => { type => 'string', pattern => '^[\w]+$', minLength => 1, maxLength => 255 },
    }
};

sub __validate_mounts {
    my ($self, $params) = @_;
    my $validator = Main::JSON::Validator->new;
    $validator->schema($__system_user_mounts_schema);

    return $validator->validate($params);
}

sub add_mount {
    my ($self, $params) = @_;
    my $c = $self->c;

    my @errors = $self->__validate_mounts($params);
    if ( $errors[0] ) {
        $self->jsonrpc_error( \@errors );
    }

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        system_user => $$params{system_user},
        name => $$params{name},
    })->next;

    if ( $exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/name',
                    message => 'Mount exist in your mounts list',
                }
            ]);

        return;
    }

    my $mount = $c->model('DB::Mount')->create({
        creator => $c->user->id,
        system_user => $$params{system_user},
        name => $$params{name},
        mount_folder => $$params{mount_folder},
        storage_url => $$params{storage_url},
        backend_login => $$params{backend_login},
        backend_password => $$params{backend_password},
        fs_passphrase => $$params{fs_passphrase},
    });

    $self->getObject('Object::Mount', c => $c, mount => $mount)->save_authinfo2;

    return $self->list_mounts($params);
}

sub rm_mount {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    # umount before delete
    $self->getObject('Object::Mount', c => $c, mount => $exist)->clean;

    my $system_user = $exist->get_column('system_user');
    $exist->delete;

    return $self->list_mounts({system_user => $system_user});
}

sub edit_mount {
    my ($self, $params) = @_;
    my $c = $self->c;

    my @errors = $self->__validate_mounts($params);
    if ( $errors[0] ) {
        $self->jsonrpc_error( \@errors );
    }

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    my $mount = $self->getObject('Object::Mount', c => $c, mount => $exist);

    # umount before generating the authinfo2
    $mount->umount;

    $exist->update({
        name => $$params{name},
        mount_folder => $$params{mount_folder},
        storage_url => $$params{storage_url},
        backend_login => $$params{backend_login},
        backend_password => $$params{backend_password},
        fs_passphrase => $$params{fs_passphrase},
    });

    # Generate the authinfo2
    $mount->save_authinfo2;

    return $self->list_mounts({system_user => $exist->get_column('system_user')});
}

sub mount_authinfo2 {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    my $mount = $self->getObject('Object::Mount', c => $c, mount => $exist);
    return $mount->save_authinfo2;
}

sub mount_mkfs {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    my $mount = $self->getObject('Object::Mount', c => $c, mount => $exist);
    return $mount->mkfs;
}

sub mount_remount {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    my $mount = $self->getObject('Object::Mount', c => $c, mount => $exist);
    return $mount->remount;
}

sub mount_umount {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    my $mount = $self->getObject('Object::Mount', c => $c, mount => $exist);
    return $mount->umount;
}

sub mount_stat {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::Mount')->search({
        creator => $c->user->id,
        id => $$params{id},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/id',
                    message => 'Mount does not exist',
                }
            ]);

        return;
    }

    my $mount = $self->getObject('Object::Mount', c => $c, mount => $exist);
    return $mount->stat;
}

sub google_key {
    my ($self, $params) = @_;
    my $c = $self->c;

    my $exist = $c->model('DB::SystemUser')->search({
        owner => $c->user->id,
        id => $$params{system_user},
    })->next;

    if ( !$exist ) {
        $self->jsonrpc_error(
            [   {   path    => '/system_user',
                    message => 'User does not exist in your system users list',
                }
            ]);

        return;
    }

    my $result = $self->forkit({
        response_type => 'google-key',
        user => $$params{system_user},
        command => "s3ql_oauth_client",
    });

    return $result;
}

no Moose;

=head1 NAME

Pluton - Catalyst based application

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO


=head1 AUTHOR

Rolando González Chévere <rolosworld@gmail.com>

=head1 LICENSE

 Copyright (c) 2017 Rolando González Chévere <rolosworld@gmail.com>

 This file is part of Pluton.

 Pluton is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License version 3
 as published by the Free Software Foundation.

 Pluton is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Pluton.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
