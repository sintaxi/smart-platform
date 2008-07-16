use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "RSP",
  VERSION_FROM => 'lib/RSP/Server.pm',
  PREREQ_PM => {
    'File::Spec' => 0,
    'HTTP::Response' => 0,
    'HTTP::Daemon' => 0,
    'HTTP::Request' => 0,
    'Set::Scalar' => 0,
    'Data::UUID::Base64URLSafe' => 0,
    'Template' => 0,
    'Scalar::Util' => 0,
    'JavaScript' => 0,
    'URI::QueryParam' => 0,
    'URI::Escape' => 0,
    'Digest::MD5' => 0,
    'MIME::Types' => 0,
    'Config::Tiny' => 0,
    'Net::OpenID::Consumer' => 0,
    'JSON::XS' => 0,
    'LWPx::ParanoidAgent' => 0,
    'DBI' => 0,
    'DBD::SQLite' => 0,
    'POSIX' => 0,
    'IO::File' => 0,
    'Module::Load' => 0,
    'URI' => 0,    
  }
);