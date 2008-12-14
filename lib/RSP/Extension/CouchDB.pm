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
  
      search => sub {
        my $type = shift;
        my $tmpl = shift;
        my $mv = $class->create_map_view( $type, $tmpl );
        my $docs = [
          map { 
            my $doc = $cdb->newDoc( $_->{id} );
            $doc->retrieve;
            $doc->data->{js};
          } @{ $cdb->tempView({ 'map' => $mv })->{rows} } 
        ];
        return $docs;
      },
  
      ## Removes a document from CouchDB
      remove => sub {
        my $type = shift;
        my $id   = shift;
        
        my $doc = $cdb->newDoc( $class->cid( $type, $id ) );
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
        print "CouchDB ID for type $type & id $id is $cid\n";
        my $doc = $cdb->newDoc( $cid );
        $doc->retrieve;

        return $doc->data->{js};
      },
  
      ## Saves a document to CouchDB
      'write' => sub {
        my $type  = shift;
        my $obj   = shift;
        my $trans = shift;
        
        print "GOING TO SAVE OBJECT $obj OF TYPE $type\n";
        
        if (!$obj->{id}) { die "no id" }
        
        my $id  = $class->cid( $type, $obj->{id} );
        my $doc = $cdb->newDoc( $id );      
        eval {
          $doc->retrieve;
          $doc->data->{meta} = { type => $type };
          $doc->data->{js} = $obj;
          $doc->update;
        };
        if ($@) {
          $doc->data->{js} = $obj;
          $doc->create;
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
  $text .= q!) ) this.emit();}!;

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
