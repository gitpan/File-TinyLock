use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'           => 'File::TinyLock',
    'VERSION_FROM'   => 'TinyLock.pm', # finds $VERSION
    'PREREQ_PM'      => {},
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'TinyLock.pm',
       AUTHOR        => 'Jeremy Kister <http://jeremy.kister.net/>') : ()),
);
