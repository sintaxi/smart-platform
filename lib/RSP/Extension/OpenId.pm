
package RSP::Extension::OpenId;

use strict;
use warnings;

use LWPx::ParanoidAgent;
use Net::OpenID::Consumer;
use Data::UUID::Base64URLSafe;

use base 'RSP::Extension';

## should use a module to do this really, but there we go...
sub decode_uri {
  my $stringtodecode=shift;
  $stringtodecode =~ tr/\+/ /s;
  $stringtodecode =~ s/%([A-F0-9][A-F0-9])/pack("C", hex())/ieg;
  return $stringtodecode;
}

sub extension_name {
  return "system.openid";
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
        if (!$sec) { 
	  RSP::Error->throw("no secret");
	}
        my ($host, $port) = split(/:/, $tx->request->headers->host);
        my $trust_root = $tx->request->url->clone;
        $trust_root->scheme('http');
        $trust_root->host( $host );
        if ( $port ) {
          $trust_root->port( $port );
        }
        $trust_root->path(Mojo::Path->new);
        $trust_root->query( Mojo::Parameters->new );

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
