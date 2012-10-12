/*

== Definition: archive::download

Archive downloader with integrity verification.

Parameters:

- *$url: 
- *$digest_url:
- *$digest_string: Default value "" 
- *$digest_type: Default value "md5".
- *$timeout: Default value 120.
- *$src_target: Default value "/usr/src".
- *$allow_insecure: Default value false.

Example usage:

  archive::download {"apache-tomcat-6.0.26.tar.gz":
    ensure => present,
    url => "http://archive.apache.org/dist/tomcat/tomcat-6/v6.0.26/bin/apache-tomcat-6.0.26.tar.gz",
  }
  
  archive::download {"apache-tomcat-6.0.26.tar.gz":
    ensure => present,
    digest_string => "f9eafa9bfd620324d1270ae8f09a8c89",
    url => "http://archive.apache.org/dist/tomcat/tomcat-6/v6.0.26/bin/apache-tomcat-6.0.26.tar.gz",
  }

  archive::download { "jdk-7u7-linux-i586.tar.gz":
    ensure        => present,
    url           => "http://download.oracle.com/otn-pub/java/jdk/7u7-b10/jdk-7u7-linux-i586.tar.gz",
    agent         => "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.1.16) Gecko/20120421 Firefox/11.0",
    cookie        => "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F",
    checksum      => false,
  }
   
*/
define archive::download (
  $ensure         = present, 
  $url, 
  $checksum       = true,
  $digest_url     = "",
  $digest_string  = "",
  $digest_type    = "md5",
  $cookie         = "",
  $agent          = "",
  $timeout        = 120,
  $src_target     = "/usr/src",
  $allow_insecure = false) {

  $cookie_arg = $cookie ? { 
    /(.*)/    => "-b \"$1\"",
    default => ""
  }

  $agent_arg = $agent ? {
    /(.*)/    => "--user-agent \"$1\"",
    default => ""  
  }

  $insecure_arg = $allow_insecure ? {
    true => "-k",
    default => "",
  }

  if !defined(Package['curl']) {
    package{'curl':
      ensure => present,
    }
  }

  Exec {
    path => "/home/vagrant/.rvm/gems/ruby-1.9.3-p194/bin:/home/vagrant/.rvm/gems/ruby-1.9.3-p194@global/bin:/home/vagrant/.rvm/rubies/ruby-1.9.3-p194/bin:/home/vagrant/.rvm/bin:/usr/lib64/ccache:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/vagrant/.rvm/bin:/sbin:/usr/sbin:/home/vagrant/.local/bin:/home/vagrant/bin"
  }

  case $checksum {
    true : {
      case $digest_type {
        'md5','sha1','sha224','sha256','sha384','sha512' : { 
          $checksum_cmd = "${digest_type}sum -c ${name}.${digest_type}" 
        }
        default: { fail "Unimplemented digest type" }
      }
    
      if $digest_url != "" and $digest_content != "" {
        fail "digest_url and digest_content should not be used together !"
      }
    
      if $digest_content == "" {
    
        case $ensure {
          present: {
    
            if $digest_url == "" {
              $digest_src = "${url}.${digest_type}"
            } else {
              $digest_src = $digest_url
            }
            exec {"download digest of archive $name":
              command => "curl ${cookie_arg} ${agent_arg} -L ${insecure_arg} -o ${src_target}/${name}.${digest_type} ${digest_src}",
              creates => "${src_target}/${name}.${digest_type}",
              timeout => $timeout,
              notify  => Exec["download archive $name and check sum"],
              require => Package["curl"],
            }
    
          }
          absent: {
            file{"${src_target}/${name}.${digest_type}":
              ensure => absent,
              purge => true,
              force => true,
            }
          }
        }
      }
    
      if $digest_string != "" {
        case $ensure {
          present: {
            file {"${src_target}/${name}.${digest_type}":
              ensure => $ensure,
              content => "${digest_string} *${name}",
              notify => Exec["download archive $name and check sum"],
            }
          }
          absent: {
            file {"${src_target}/${name}.${digest_type}":
              ensure => absent,
              purge => true,
              force => true,
            }
          }
        }
      }
    }
    false :  { notice "No checksum for this archive" }
    default: { fail ( "Unknown checksum value: '${checksum}'" ) }
  }
 
  case $ensure {
    present: {
      exec {"download archive $name and check sum":
        command   => "curl ${cookie_arg} ${agent_arg} -L ${insecure_arg} -o ${src_target}/${name} ${url}",
        creates   => "${src_target}/${name}",
        logoutput => true,
        timeout   => $timeout,
        require   => Package["curl"],
        notify => $checksum ? {
          true    => Exec["rm-on-error-${name}"],
          default => undef,
        },
        refreshonly => $checksum ? {
          true    => true,
          default => undef,
        },
      }

      exec {"rm-on-error-${name}":
        command     => "rm -f ${src_target}/${name} ${src_target}/${name}.${digest_type} && exit 1",
        unless      => $checksum_cmd,
        cwd         => $src_target,
        refreshonly => true,
      }
    }
    absent: {
      file {"${src_target}/${name}":
        ensure => absent,
        purge => true,
        force => true,
      }
    }
    default: { fail ( "Unknown ensure value: '${ensure}'" ) }
  }
}
