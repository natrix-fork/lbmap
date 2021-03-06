package lbmap::Passive::Cookie;

use strict;
use warnings;
use lbmap::lbmap;

=head1 NAME

lbmap::Passive::Cookie - Detects and decodes (where possible) known cookies.
- F5 BIGIP cookie data to enumerate backends
- BlueCoat SG high availability cookies
- Kemp loadbalance cookies

=head1 VERSION

Version 0.1

=cut

# Globals
our $VERSION = '0.1';
our $AUTHOR = 'Eldar Marcussen - http://www.justanotherhacker.com';

=head1 DESCRIPTION
lbmap::Passive::Cookie Detects and if possible decodes known cookies, such as persistent pool information or routes.
=cut

sub new {
    my ($class, $parent) = @_;
    my $self = {};
    $self->{'parent'} = $parent;
    bless $self, $class;
    $self->{'parent'}->add_passive_detect('BIGipv4regex', 'Set-Cookie: .*=\d+\.\d+\.\d{4}', \&decode_bigipv4 );
    $self->{'parent'}->add_passive_detect('BIGipv4', 'Set-Cookie: .*BIGip.*=\d+\.\d+\.\d+', \&decode_bigipv4 );
    $self->{'parent'}->add_passive_detect('BIGipv6', 'Set-Cookie: .*BIGip.*=vi.*', \&decode_bigipv6 );
    $self->{'parent'}->add_passive_detect('BIGiprd', 'Set-Cookie: .*BIGip.*=rd.+o00000000000000000000ffff.+o.+', \&decode_bigiproutedomain );
    $self->{'parent'}->add_passive_detect('BlueCoatHA', 'Set-Cookie: .*BC_HA_[^=]+=', \&detect_bluecoat );
    $self->{'parent'}->add_passive_detect('KempLB', 'Set-Cookie: .*kt=\d+\.\d+\.\d+\.\d+', \&detect_kempLB );
    return $self;
}


sub decode_bigipv4 {
    my ($parent, $http_response) = @_;
    if ($http_response =~ m/Set-Cookie: (.*)=(\d+)\.(\d+)\.(\d+)/o) {
        my ($pool, $host, $port, $wat) = ($1, $2, $3, $4);
        my $backend = join ".", map {hex} reverse ((sprintf "%08x", $host) =~ /../g);
        $backend.=":".hex join "", reverse((sprintf "%02x", $port) =~ /../g);
        $parent->add_result('backend',$backend);
        $parent->add_result('loadbalancer', 'BIGIP');
    }
}

sub decode_bigipipv6 {
    my ($parent, $http_response) = @_;
    if ($http_response =~ m/(BIGip.*)=vi(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})\.(.+)/) {
        my ($pool, $ipv6, $port) = ($1, "$2:$3:$4:$5:$6:$7", $8);
        my $backend = "$ipv6:$port";
        $parent->add_result('backend', $backend);
        $parent->add_result('loadbalancer', 'BIGIP');
    }
}

sub decode_bigiproutedomain {
    my ($parent, $http_response) = @_;
    if ($http_response =~ m/(BIGip.*)=rd(.+)o00000000000000000000ffff(..)(..)(..)(..)o(.+)/) {
        my ($pool, $route_id, $ip1, $ip2, $ip3, $ip4, $port) = ($1, $2, $3, $4, $5, $6, $7);
        my $backend = hex($ip1).".".hex($ip2).".".hex($ip3).".".hex($ip4).":$port";
        $parent->add_result('backend', $backend);
        $parent->add_result('loadbalancer', 'BIGIP');
    }
}

sub detect_bluecoat {
    my ($parent, $http_response) = @_;
    if ($http_response =~ m/BC_HA_/) {
        $parent->add_result('loadbalancer', 'BlueCoat');
    }
}

sub detect_kempLB {
    my ($parent, $http_response) = @_;
    if ($http_response =~ m/kt=\d+\.\d+\.\d+\.\d+/) {
        $parent->add_result('loadbalancer', 'BlueCoat');
    }
}


1;
