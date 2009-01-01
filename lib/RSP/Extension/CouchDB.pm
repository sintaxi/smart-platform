package RSP::Extension::CouchDB;

use strict;
use warnings;

use Digest::MD5 'md5_hex';
use CouchDB::Client;

sub provides {
  my $class = shift;
  my $tx    = shift;

  my $cdb   = $class->couch( $tx );

  return {
    datastore => {

      ## okay, so this is a really nasty big hack, until I can come up with
      ##   something better.  It may be that I need to create some external
      ##   indexing or something.  Or maybe being able to pass a function in
      ##   as a query, that gets md5d and turned into a view, or something
      ##   crazy like that.  Bah.  Indexing sucks.
      search => sub {
        my $type = shift;
        my $tmpl = shift;
        my $mv;
        if ( keys %$tmpl ) {
          $mv = $class->create_map_view( $type, $tmpl );
        } else {
          $mv = qq!function() { if ( this.meta.type == '$type' ) emit(this.js.id, this) }!;
        }
                
        my $docs = [
          map {
            my $id = $_->{id};
            my $obj = eval { JSON::XS::decode_json( $tx->cache->get( $id ) ) };
            if (!$obj) {
              my $doc = $cdb->newDoc( $_->{id} );
              $doc->retrieve;
              $obj = $doc->data->{js};
              $tx->cache->set( $id, JSON::XS::encode_json( $obj ) );
            }
            $obj;
          } @{ $cdb->tempView({ 'map' => $mv })->{rows} } 
        ];
        return $docs;
      },
  
      ## Removes a document from CouchDB
      remove => sub {
        my $type = shift;
        my $id   = shift;
        
        my $cid = $class->cid( $type, $id );

        $tx->cache->delete( $cid );

        my $doc = $cdb->newDoc( $cid );
        $doc->retrieve;
        $doc->delete;
      },
  
      ## Gets a document from CouchDB
      get  => sub {
        my $type = shift;
        my $id   = shift;
        
        if (!$type) { die "no type"; }
        if (!$id)   { die "no id"; }

        my $cid = $class->cid( $type, $id );

        my $obj = eval { JSON::XS::decode_json( $tx->cache->get( $cid ) ) };
        if ( !$obj ) {
          eval {
            my $doc = $cdb->newDoc( $cid );
            $doc->retrieve;
            $obj = $doc->data->{js};
            $tx->cache->set( $cid,  JSON::XS::encode_json( $obj ) );
          };
          if ($@) {
            return undef;
          }
        }
        return $obj;
      },
  
      ## Saves a document to CouchDB
      'write' => sub {
        my $type  = shift;
        my $obj   = shift;
        my $trans = shift;
        
        if (!$obj->{id}) { die "no id" }
        
        my $id  = $class->cid( $type, $obj->{id} );
        my $saved = $tx->cache->set( $id, JSON::XS::encode_json( $obj ) );
        if ( $saved && $trans ) {
          return;
        }

        my $doc = $cdb->newDoc( $id );      
        $doc->data->{meta} = { type => $type };
        eval {
          $doc->retrieve;
          $doc->data->{js} = $obj;
          $doc->update;
        };
        if ($@) {
          $doc->data->{js} = $obj;
          $doc->create;
          return 1;
        }
      }

    }
  }
}

sub cid {
  my $class = shift;
  my $type  = shift;
  my $id    = shift;
  md5_hex( $type, $id );
}

##
## this creates a piece of code to generate a view...
##
sub create_map_view {
  my $class    = shift;
  my $type     = shift;
  my $template = shift;
  my $text = q!
Document = {

  'isType': function( aType ) {
    if ( this.meta.type == aType ) return true;
  },

  'matches': function( anExample ) {
    for ( var key in anExample ) {
      if ( this.js[key] && this.js[key] == anExample[key] ) {
        return true;
      }
    }
  },

  'emit': function() {
    emit( this._id, this );
  }

};

function() {
  this.__proto__ = Document;
  if ( this.isType( '!;
  
  $text .= $type . "') && this.matches( ";
  
  $text .= JSON::XS::encode_json( $template );
  $text .= q!) ) this.emit();
  }!;

  return $text;
}

sub couch {
  my $self = shift;
  my $tx   = shift;
  if (!$tx) { die "no transaction" }
  
  my $couch = $tx->{ext}->{couch}->{conn} ||= CouchDB::Client->new;

  my @fqdn   = split(/\./, $tx->host->hostname);
  my $dbname = join("_", reverse(@fqdn));

  my $db = $tx->{ext}->{couch}->{db} ||= $couch->newDB( $dbname );
  eval {
    $db->create;
  };
  return $db;
}



1;
