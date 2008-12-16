use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'RSP',
  VERSION_FROM => 'lib/RSP.pm',
  PREREQ_PM => {
    'Application::Config' => 0,
    'Mojo'                => 0,
    'MIME::Types'         => 0,
    'Hash::Merge::Simple' => 0,
    'Template'            => 0,
    'Digest::MD5'         => 0,
    'JSON:XS'             => 0,
    'Scalar::Util'        => 0,
    'JavaScript'          => 0,
    'Module::Load'        => 0,
    'LWPx::ParanoidAgent' => 0,
    'Cache::Memcached::Fast' => 0,
    'CouchDB::Client'       => 0,
    'Net::OpenID::Consumer' => 0,
    'Class::Accessor::Chained' => 0,
    'Data::UUID::Base64URLSafe' = 0,
  }
);