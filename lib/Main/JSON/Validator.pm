package Main::JSON::Validator;
use Modern::Perl;
use Moose;
use namespace::autoclean;
use Email::Valid;
use Data::Validate::URI ();

extends 'JSON::Validator';

our $__email_validator = Email::Valid->new;
sub _build_formats {
    my ($self) = @_;
    my $formats = $self->SUPER::_build_formats;
    $formats->{email} = sub {
        return $__email_validator->address($_[0]);
    };
    $formats->{uri} = sub {
        return Data::Validate::URI->new->is_uri($_[0]);
    };
    return $formats;
}

1;
__END__

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
