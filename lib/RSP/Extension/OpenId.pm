package RSP::Extension::OpenId;

use strict;
use warnings;

use LWPx::ParanoidAgent;
use Net::OpenID::Consumer;
use Data::UUID::Base64URLSafe;

sub provide {
  my $class = shift;
  my $tx    = shift;
  my $ug  = Data::UUID::Base64URLSafe->new;
  
  return (
    openid => {
      validate => sub {
        my $claimed = shift;
        my $return  = shift;

        $return = 'http://'.$tx->{host} . ((RSP->config->{daemon}->{LocalPort} != 80) ? ':' . RSP->config->{daemon}->{LocalPort} : '') . $return,

        $tx->log("checking $claimed for valid identity...");

        my $sec = $ug->create_b64_urlsafe;

        my $csr = Net::OpenID::Consumer->new(
          ua    => LWPx::ParanoidAgent->new,
          args  => $tx->{request}->uri->query_form_hash,
          consumer_secret => $sec,
          required_root => 'http://'.$tx->{host} . ((RSP->config->{daemon}->{LocalPort} != 80) ? ':' . RSP->config->{daemon}->{LocalPort} : '') . $tx->{request}->{uri},
        );        
        
        my $cid = $csr->claimed_identity( $claimed );
        if (!$cid) {
          $tx->log("didn't get a handle back for some reason: " . $csr->err);
          return {};
        }
        my $check_url = $cid->check_url(
          return_to  => $return,
          trust_root => 'http://'.$tx->{host} . ((RSP->config->{daemon}->{LocalPort} != 80) ? ':' . RSP->config->{daemon}->{LocalPort} : '') . $tx->{request}->{uri},
        );
        return {
          check  => $check_url,
          secret => $sec
        }
      },
      returned => sub {
        my $sec = shift;
        my $csr = Net::OpenID::Consumer->new(
          ua    => LWPx::ParanoidAgent->new,
          args  => $tx->{request}->uri->query_form_hash || {},
          consumer_secret => $sec,
          required_root => 'http://'.$tx->{host} . ((RSP->config->{daemon}->{LocalPort} != 80) ? ':' . RSP->config->{daemon}->{LocalPort} : '') . $tx->{request}->{uri},,
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
  );
}

1;
