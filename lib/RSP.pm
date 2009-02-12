package RSP;

use strict;
use warnings;

use Cwd;
use base 'Mojo';
use Number::Bytes::Human 'format_bytes';
use Darwin::Process::Memory;
use Scalar::Util qw( weaken );
our $VERSION = '1.2';
use Application::Config 'rsp.conf';

use RSP::Transaction::Mojo;

sub sample_memory {
  return (
      #format_bytes( 
	  Darwin::Process::Memory::resident(),
      #),
      #format_bytes(
	  Darwin::Process::Memory::virtual()
      #),
      );
}

sub handler {
  my ($self, $tx) = @_;

  my ($rstart, $vstart) = sample_memory();
  print STDERR sprintf("$$ start: resident: %s, virtual: %s\n", $rstart, $vstart);
  my $rsptx = RSP::Transaction::Mojo->new
                                    ->request( $tx->req )
				    ->response( $tx->res );

  eval {
    $rsptx->process_transaction;    
  };
  if ($@) {
    $tx->res->code( 500 );
    $tx->res->headers->content_type('text/plain');
    $tx->res->body($@);
  }

  $rsptx->request( undef );
  $rsptx->response( undef );
  $rsptx = undef;

  my ($rend, $vend) = sample_memory();
  print STDERR sprintf("$$ end: resident: %s, virtual: %s, resident diff: %s\n", $rend, $vend, format_bytes( $rend - $rstart ));

  return $tx;
}

sub root {
  my $self = shift;
  my $root = $self->config->{_}->{root};
  if (!$root) {
    $root = getcwd();
  }
  return $root;
}

1;
