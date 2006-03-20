package WWW::Hatena::WanWanWorld;

use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '0.01';

use base qw(WWW::Hatena::Scraper);
use Digest::MD5 qw(md5_base64);
use JSON;
use Location::GeoTool;
use Jcode;

sub new {
    my $self = shift;
    my %opts = @_;
    $opts{labo} = 1;

    $opts{user_check_code} = sub {
        my $self = shift;
        my $content = shift;

        my ($user) = $content =~ /var\smyName\s*=\s*'([^']+)';/;
        $self->user($user);
        my ($long,$lat) = $content =~ /var\sstart\s*=\s*\[([\d\.]+),\s*([\d\.]+)\];/;
        $self->lat($lat);
        $self->long($long);

        $self->user;
    };
    $opts{user_check_url} = "http://world.hatelabo.jp/";

    $self = $self->SUPER::new(%opts);
    $self->logout_url("http://world.hatelabo.jp/logout");
    return $self;
}

sub lat { &WWW::Hatena::Scraper::_getset; }
sub long { &WWW::Hatena::Scraper::_getset; }
sub friends { &WWW::Hatena::Scraper::_getset; }
sub arounds { &WWW::Hatena::Scraper::_getset; }
sub markers { &WWW::Hatena::Scraper::_getset; }
sub voice { &WWW::Hatena::Scraper::_getset; }
sub charcode { &WWW::Hatena::Scraper::_getset; }
sub json {
    my $self = shift;
    $self->{'json'} ||= JSON->new(unmapping => 1, quotapos => 1 , barekey => 1); 
}

sub position {
    my $self = shift;
    if (@_ == 2) {
        $self->lat(shift);
        $self->long(shift);
    } elsif (@_ != 0) {
        croak ("Number of parameters are invalid");
    }
    return ($self->lat,$self->long);
}

sub get_around {
    my $self = shift;
    my $km = shift;
    my $rkm = md5_base64($self->rk);
    my $voice = $self->encoded_voice();
    my ($lat,$long,$minY,$minX,$maxY,$maxX) = $self->get_minmax($km);
    my $content = "z=1&lat=${long}&lng=${lat}&voice=${voice}&rkm=${rkm}&minX=${minX}&maxX=${maxX}&minY=${minY}&maxY=${maxY}&_=";
    $self->arounds($self->json->jsonToObj($self->get_content('http://world.hatelabo.jp/position',$content)));
}

sub get_friend {
    my $self = shift;
    my $content = shift || '';
    my $res = $self->get_content('http://world.hatelabo.jp/friend',$content);
    if ($content eq '') {
        return $self->friends($self->json->jsonToObj($res));
    } else {
        my ($result) = $res =~ /<success>(.+)<\/success>/m; 
        return eval {$result} || 0;
    }
}

sub delete_friend {
    my $self = shift;
    my $friend = shift;
    my $rkm = md5_base64($self->rk);
    $self->get_friend("mode=delete&friendname=${friend}&rkm=${rkm}&_=");
}

sub add_friend {
    my $self = shift;
    my $friend = shift;
    my $rkm = md5_base64($self->rk);
    $self->get_friend("mode=add&friendname=${friend}&rkm=${rkm}&_=");
}

sub get_marker {
    my $self = shift;
    my $km = shift;
    my ($lat,$long,$minY,$minX,$maxY,$maxX) = $self->get_minmax($km);
    my $content = "minX=${minX}&maxX=${maxX}&minY=${minY}&maxY=${maxY}&lt=20&_=";
    $self->markers($self->json->jsonToObj($self->get_content('http://world.hatelabo.jp/marker',$content)));
}

sub add_house {
    my $self = shift;
    my ($lat,$long) = $self->position;
    my $rkm = md5_base64($self->rk);
    $self->json->jsonToObj($self->get_content('http://world.hatelabo.jp/house',"lat=${long}&lng=${lat}&mode=add&rkm=${rkm}&_="));
}

sub get_minmax {
    my $self = shift;
    my $km = shift;
    my ($lat,$long) = $self->position;
    my $loc = Location::GeoTool->create_coord($lat,$long,'wgs84','degree');
    my ($minY,$minX) = $loc->direction_vector(225,$km * 1414.21356)->to_point->array;
    my $maxX = $long * 2 - $minX;
    my $maxY = $lat * 2 - $minY;
    return ($lat,$long,$minY,$minX,$maxY,$maxX);
}

sub encoded_voice {
    my $self = shift;
    my $voice = Jcode->new($self->voice || '',$self->charcode)->utf8;
    $voice =~ s/([^0-9A-Za-z_ ])/'%'.unpack('H2',$1)/ge;
    $voice =~ s/\s/+/g;
    return $voice;
}

1;
__END__
=head1 NAME

WWW::Hatena::WanWanWorld - Client class to access Hatena Wan Wan World

=head1 SYNOPSIS

    use WWW::Hatena::WanWanWorld;

    ## Login
    my $www = WWW::Hatena::WanWanWorld->new;
    my $username = $www->login('username','password') or die "Login failed!";

    ## Prepare
    $www->position(35.657540,139.702341);
    $www->voice('BowWow!!');

    ## To set own position and voice, and get around users in 2km.
    my $arounds = $www->get_around(2);

    ## To get own friend.
    my $friends = $www->get_friend;

    ## To get markers (house, or so) in 2km around.
    my $markers = $www->get_marker(2);

    ## To add other user to own friend.
    $www->add_friend("otheruser");

    ## To add other user to own friend.
    $www->delete_friend("otheruser");

    ## To put own house here.
    $www->add_house;

    ## Logout.
    $www->logout;

=head1 DESCRIPTION

I<WWW::Hatena::WanWanWorld> is a client to operate your own dog in Hatena 
Wan Wan World from perl.

=head1 CONSTRUCTOR

=over 4

=item C<new>

my $www = WWW::Hatena::Scraper->new([ %opts ]);

You can set the C<ua> option in constructor.

=over 8

=item ua

If you want to reuse I<LWP::UserAgent> object, set it to this option.

=back

=back

=head1 METHODS

=item $www->B<login>($userid,$password)

=item $www->B<login>($cookie)

Login to Hatena Wan Wan World.
Return value is Hatena user id, and if undef returns, login failed.

=item $www->B<logout>

Logout from Hatena Wan Wan World.

=item $www->B<user>

Returns user id if login successed.

=item $www->B<rk>

Returns login cookie if login successed.
Give this value to login method later, you can relogin, unless it hasn't
expired.

=item $www->B<position>($latitude,$longitude)

=item $www->B<position>

Set or get user's(dog's?) position in latitude,longitude array.

=item $www->B<lat>($latitude)

=item $www->B<lat>

Set or get latitude of user's(dog's?) position.

=item $www->B<long>($longitude)

=item $www->B<long>

Set or get longitude of user's(dog's?) position.

=item $www->B<voice>($voice)

=item $www->B<voice>

Set or get user's(dog's?) voice to show.

=item $www->B<charcode>($charcode)

Set character code of voice string.
Module detect character code automatically, but sometimes may failed.
You want to make it clear, use set character code to this method.

=item $www->B<get_around>($km)

Send position and voice data to Hatena Wan Wan World's server.
Return object is, other user's list of around $km kilo meters.
Object is just raw hash-ref translated from JSON response.
If $km value is too big, (maybe $km > 9), server returns no value.
This may specification of Hatena Wan Wan World.

=item $www->B<arounds>

Return same object of get_around method returns.
You can get it later by this method.

=item $www->B<get_friend>

Return object is, friend's list of user.
Object is just raw array-ref translated from JSON response.

=item $www->B<friends>

Return same object of get_friend method returns.
You can get it later by this method.

=item $www->B<get_marker>($km)

Return object is, marker (house, or so) list of around $km kilo meters.
Object is just raw hash-ref translated from JSON response.

=item $www->B<markers>

Return same object of get_marker method returns.
You can get it later by this method.

=item $www->B<add_friend>($username)

Add other user to user's friend.
Return 1 if succesed, 0 if failed.

=item $www->B<delete_friend>($username)

Delete other user to user's friend.
Return 1 if succesed, 0 if failed.

=item $www->B<add_house>

Build user's own house at user's position.

=item $www->B<err>

Returns the last error, in form "errcode: errtext"

=item $www->B<errcode>

Returns the last error code.

=item $www->B<errtext>

Returns the last error text.

=back

=head1 NOTICE

Area detectation(calcurating minimum and maximum longitude/latitude) logic
of B<get_around> method and B<get_marker> method is just poor hacked.
It is only work around in Japan, typically not worked near the pole.

All raw objects translated from JSON has mistakes.
In these object, attribute B<lat> means B<longitude>, B<lng> means B<latitude>.
This is error of Hatena itself.
Take care.
In perl API, there are no such mistakes.

=head1 TODO

Make user-friendry class to handle objects translated from JSON.

=head1 COPYRIGHT

This module is Copyright (c) 2006 OHTSUKA Ko-hei.
All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.
If you need more liberal licensing terms, please contact the
maintainer.

=head1 WARRANTY

This is free software. IT COMES WITHOUT WARRANTY OF ANY KIND.

=head1 SEE ALSO

Hatena Wan Wan World website:  L<http://world.hatelabo.jp/>

L<WWW::Hatena::Scraper> -- part of this module

=head1 AUTHORS

OHTSUKA Ko-hei <nene@kokogiko.net>

=cut