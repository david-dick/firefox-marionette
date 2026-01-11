package Firefox::Marionette::GeoLocation;

use strict;
use warnings;
use Encode();
use overload q[""] => '_lat_long';
use charnames qw(:full);

our $VERSION = '1.70';

sub _MINUTES_IN_ONE_HOUR             { return 60 }
sub _MINUTES_IN_ONE_DEGREE           { return 60 }
sub _SECONDS_IN_ONE_MINUTE           { return 60 }
sub _NUMBER_TO_ADD_PRIOR_TO_ROUNDING { return 0.5 }
sub _NEGATIVE_OFFSET                 { return -1 }

my $latitude_code  = 'lat';
my $longitude_code = 'lng';

sub new {
    my ( $class, @parameters ) = @_;
    my %parameters;
    if ( ( scalar @parameters ) == 1 ) {
        %parameters = %{ $parameters[0] };
    }
    else {
        %parameters = @parameters;
    }
    my $self     = bless {}, $class;
    my %mappings = (
        latitude          => $latitude_code,
        longitude         => $longitude_code,
        long              => $longitude_code,
        lon               => $longitude_code,
        altitude_accuracy => 'altitudeAccuracy',
        timeZone          => 'timezone_offset',
        countryCode       => 'country_code',
        country_code2     => 'country_code',
    );
    my %keys = (
        lng              => 1,
        lat              => 1,
        altitude         => 1,
        accuracy         => 1,
        heading          => 1,
        speed            => 1,
        altitudeAccuracy => 1,
        speed            => 1,
        timezone_offset  => 1,
        timezone_name    => 1,
        country_code     => 1,
    );
    foreach my $original ( sort { $a cmp $b } keys %parameters ) {
        if ( exists $mappings{$original} ) {
            $self->{ $mappings{$original} } = $parameters{$original};
        }
        elsif ( $keys{$original} ) {
            $self->{$original} = $parameters{$original};
        }
    }
    if ( defined $self->{timezone_offset} ) {
        if ( $self->{timezone_offset} =~ /^([+-])(\d{1,2}):(\d{1,2})$/smx ) {
            $self->{timezone_offset} =
              $self->_calculate_offset_for_javascript( $1, $2, $3 );
        }
    }
    elsif ( defined $parameters{time_zone}{current_time} ) {
        if (
            $parameters{time_zone}{current_time} =~ /([+-])(\d{2})(\d{2})$/smx )
        {
            $self->{timezone_offset} =
              $self->_calculate_offset_for_javascript( $1, $2, $3 );
        }
    }
    if ( defined $parameters{time_zone}{name} ) {
        $self->{tz} = $parameters{time_zone}{name};
    }
    if ( defined $self->{country_code} ) {
        if ( $self->{country_code} !~ /^[[:upper:]]{2}$/smx ) {
            delete $self->{country_code};
        }
    }
    return $self;
}

sub _calculate_offset_for_javascript {
    my ( $self, $sign, $hours, $minutes ) = @_;
    my $offset = $hours * _MINUTES_IN_ONE_HOUR() + $minutes;
    if ( $sign ne q[-] ) {
        $offset *= _NEGATIVE_OFFSET();
    }
    return $offset;
}

sub _lat_long {
    my ($self) = @_;

    # https://www.wikihow.com/Write-Latitude-and-Longitude
    my $lat_direction = $self->latitude() >= 0  ? q[N] : q[S];
    my $lng_direction = $self->longitude() >= 0 ? q[E] : q[W];
    my $lat_degrees   = int abs $self->latitude();
    my $lng_degrees   = int abs $self->longitude();
    my $lat_minutes   = int(
        ( ( abs $self->latitude() ) - $lat_degrees ) * _MINUTES_IN_ONE_DEGREE()
    );
    my $lng_minutes = int( ( ( abs $self->longitude() ) - $lng_degrees ) *
          _MINUTES_IN_ONE_DEGREE() );
    my $lat_seconds = int(
        (
            (
                (
                    ( ( abs $self->latitude() ) - $lat_degrees ) *
                      _MINUTES_IN_ONE_DEGREE()
                ) - $lat_minutes
            ) * _SECONDS_IN_ONE_MINUTE()
        ) + _NUMBER_TO_ADD_PRIOR_TO_ROUNDING()
    );
    my $lng_seconds = int(
        (
            (
                (
                    ( ( abs $self->longitude() ) - $lng_degrees ) *
                      _MINUTES_IN_ONE_DEGREE()
                ) - $lng_minutes
            ) * _SECONDS_IN_ONE_MINUTE()
        ) + _NUMBER_TO_ADD_PRIOR_TO_ROUNDING()
    );
    return
"$lat_degrees\N{DEGREE SIGN}$lat_minutes'$lat_seconds\"$lat_direction,$lng_degrees\N{DEGREE SIGN}$lng_minutes'$lng_seconds\"$lng_direction";
}

sub TO_JSON {
    my ($self) = @_;
    my $json = {};
    foreach my $key ( sort { $a cmp $b } keys %{$self} ) {
        if ( $key =~ /^(?:$longitude_code|$latitude_code)$/smx ) {
            $json->{location}->{$key} = $self->{$key};
        }
        elsif ( $key =~ /^(?:accuracy|altitude)$/smx ) {
            $json->{$key} = $self->{$key};
        }
    }
    return $json;
}

sub latitude {
    my ($self) = @_;
    return $self->{$latitude_code};
}

sub longitude {
    my ($self) = @_;
    return $self->{$longitude_code};
}

sub altitude {
    my ($self) = @_;
    return $self->{altitude};
}

sub accuracy {
    my ($self) = @_;
    return $self->{accuracy};
}

sub altitude_accuracy {
    my ($self) = @_;
    return $self->{altitudeAccuracy};
}

sub heading {
    my ($self) = @_;
    return $self->{heading};
}

sub speed {
    my ($self) = @_;
    return $self->{speed};
}

sub timezone_offset {
    my ($self) = @_;
    return $self->{timezone_offset};
}

sub tz {
    my ($self) = @_;
    return $self->{tz};
}

sub country_code {
    my ($self) = @_;
    return $self->{country_code};
}

sub uri {
    my ($self) = @_;
    my $uri    = q[geo:] . join q[,], $self->latitude(), $self->longitude(),
      ( defined $self->altitude() ? $self->altitude() : () );
    if ( defined $self->accuracy() ) {
        $uri = join q[;], $uri, q[u=] . $self->accuracy();
    }
    return URI->new($uri);
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::GeoLocation - Represents a GeoLocation for Firefox

=head1 VERSION

Version 1.70

=head1 SYNOPSIS

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(geo => { lat => -37.814, lng => 144.96332 };
    ...

=head1 DESCRIPTION

This module provides an easy interface for the L<GeoLocationCoordinates|https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates> object in Firefox 

=head1 SUBROUTINES/METHODS

=head2 accuracy

returns the accuracy of the L<latitude|/latitude> and L<longitude|/longitude> properties, expressed in meters.

=head2 altitude

returns the position's altitude in meters, relative to nominal sea level.  This value may not be defined.

=head2 altitude_accuracy

returns the accuracy of the altitude expressed in meters.  This value may not be defined.

=head2 country_code

returns the country_code (L<ISO 3166-1 alpha-2|https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2>) of the location.  This value may not be defined.

=head2 heading

returns the direction towards which the device is facing. This value, specified in degrees, indicates how far off from heading true north the device is. 0 degrees represents true north, and the direction is determined clockwise (which means that east is 90 degrees and west is 270 degrees).  This value may not be defined.

=head2 latitude

returns the position's latitude in decimal degrees.

=head2 longitude

returns the position's longitude in decimal degrees.

=head2 new

accepts an optional hash as a parameter.  Allowed keys are below;

=over 4

=item * accuracy - the accuracy of the L<latitude|/latitude> and L<longitude|/longitude> properties, expressed in meters.

=item * altitude - the accuracy of the altitude expressed in meters.

=item * altitude_accuracy - accuracy of the altitude expressed in meters.

=item * heading - the direction towards which the device is facing. This value, specified in degrees, indicates how far off from heading true north the device is. 0 degrees represents true north, and the direction is determined clockwise (which means that east is 90 degrees and west is 270 degrees).

=item * lat - see latitude.

=item * latitude - the position's latitude in decimal degrees.

=item * lon - see longitude.

=item * long - see longitude.

=item * longitude - the position's longitude in decimal degrees.

=item * lng - see longitude.

=item * speed - the velocity of the device in meters per second.

=item * tz - the timezone as an L<Olson TZ identifier|https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List>.

=back

This method returns a new C<Firefox::Marionette::GeoLocation> object.

=head2 speed

returns the velocity of the device in meters per second.  This value may not be defined.

=head2 timezone_offset

returns the timezone offset in minutes from GMT.  This value may not be defined.

=head2 tz

returns the timezone as an L<Olson TZ identifier|https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List>.  This value may not be defined.

=head2 TO_JSON

required to allow L<JSON serialisation|https://metacpan.org/pod/JSON#OBJECT-SERIALISATION> to work correctly.  This method should not need to be called directly.

=head2 uri

This method returns the object encoded as a new L<URI|URI>.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::GeoLocation requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

To report a bug, or view the current list of bugs, please visit L<https://github.com/david-dick/firefox-marionette/issues>

=head1 AUTHOR

David Dick  C<< <ddick@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic/perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
