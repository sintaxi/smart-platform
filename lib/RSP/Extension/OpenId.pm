#    This file is part of the RSP.
#
#    The RSP is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    The RSP is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with the RSP.  If not, see <http://www.gnu.org/licenses/>.
package RSP::Extension::OpenId;

use strict;
use warnings;

use LWPx::ParanoidAgent;
use Net::OpenID::Consumer;
use Data::UUID::Base64URLSafe;

sub decode_uri {
  my $stringtodecode=shift;
  print "ENCODED STRING IS $stringtodecode\n";
  $stringtodecode =~ tr/\+/ /s;
  $stringtodecode =~ s/%([A-F0-9][A-F0-9])/pack("C", hex())/ieg;
  print "DECODED STRING IS $stringtodecode\n";
  return $stringtodecode;
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $ug  = Data::UUID::Base64URLSafe->new;
  
  return {
    openid => {
      validate => sub {
        my $claimed = shift;
        my $return  = shift;

        my ($host, $port) = split(/:/, $tx->request->headers->host);

        my $trust_root = $tx->request->url->clone;
        $trust_root->query( Mojo::Parameters->new );
        $trust_root->scheme('http');
        $trust_root->host( $host );
        if ( $port ) {
          $trust_root->port( $port );
        }
        $trust_root->path(Mojo::Path->new);

        my $ret_uri = $trust_root->clone;
        $ret_uri->path( $return );

        $tx->log("return to uri is " . $ret_uri);

        my $sec = $ug->create_b64_urlsafe;

        my $csr = Net::OpenID::Consumer->new(
          ua    => LWPx::ParanoidAgent->new,
          args  => $tx->request->url->query->to_hash,
          consumer_secret => $sec,
          required_root => $trust_root->to_string,
        );        
        
        my $cid = $csr->claimed_identity( $claimed );
        if (!$cid) {
          $tx->log("didn't get a handle back for some reason: " . $csr->err);
          return {};
        }
        
        my $check_url = $cid->check_url(
          return_to  => $ret_uri->to_string,
          trust_root => $trust_root->to_string,
        );

        return {
          check  => $check_url,
          secret => $sec
        }
      },
      
      returned => sub {
        my $sec = shift;
        if (!$sec) { die "no secret" }
        my ($host, $port) = split(/:/, $tx->request->headers->host);        
        my $trust_root = $tx->request->url->clone;
        $trust_root->scheme('http');
        $trust_root->host( $host );
        if ( $port ) {
          $trust_root->port( $port );
        }
        $trust_root->path(Mojo::Path->new);
        $trust_root->query( Mojo::Parameters->new );
        
        $tx->log("trust root is " . $trust_root->to_string);
        $tx->log("Consumer Secret is $sec");
        
        my $csr = Net::OpenID::Consumer->new(
          ua    => LWPx::ParanoidAgent->new,
          args  => $tx->request->url->query->to_hash || {},
          consumer_secret => $sec,
          required_root   => $trust_root->to_string,
        );
        
        if (my $setup_url = $csr->user_setup_url) {
          return { setup => $setup_url }
        } elsif ($csr->user_cancel) {
          return { cancel => 1 }
        } elsif (my $vident = $csr->verified_identity) {
          my $verified_url = $vident->url;
          return { valid => $verified_url };
        } else {
          $tx->log("could not verify: " . $csr->err);
          return { error => 1 };
        }          
      }
    }
  };
}

1;
