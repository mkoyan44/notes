Keystone provides single point for AAA for other openstack service components.
Identity service manages the cataloges (list of available services).Each service might have multiple endponts namely internal,public,admin. 
In a production environment, different endpoint types might reside on separate networks exposed to different types of users for security reasons. For instance, the public API network might be visible from the Internet so customers can manage their clouds. The admin API network might be restricted to operators within the organization that manages cloud infrastructure. The internal API network might be restricted to the hosts that contain OpenStack services. 
Also, OpenStack supportsmultiple regions for scalability.

Server
	A centralized server provides authentication and authorization services using a RESTful interface.

Drivers
	Drivers or a service back end. They are used for accessing identity information. (for example, SQL databases or LDAP servers).

Modules
	These modules intercept service requests, extract user credentials, and send them to the centralized server for authorization. The integration between the middleware modules and OpenStack components uses the Python Web Server Gateway Interface.

Installation 

yum install yum-utils centos-release-openstack-queens.x86_64 -y
yum-config-manager --enablerepo centos-openstack-queens/x86_64 # install and enable repo
yum install -y python-openstackclient mod_ssl openstack-keystone httpd mod_wsgi mariadb-server mariadb

# install wsgi ( standardized interface between Web servers and Python Web frameworks/applications )
# mysql as back end for storing user/pass as well as catalogs

grant all privileges on *.* to 'root'@'%' identified by '111' with grant option;# grant root for remote access
grant all privileges on keystone.* to 'keystone'@'localhost' identified by 'keystone123'; # grant keyston for remote and local access
grant all privileges on keystone.* to 'keystone'@'localhost' identified by 'keystone123';
flush privileges; # make privilages

cat /etc/keystone/keystone.conf 
# keyston is plugable, so each section privides the features configuration
[DEFAULT]
[application_credential]
[assignment]
[auth]
[cache]
[catalog]
[cors]
[credential]
[database]
connection = mysql+pymysql://keystone:111@keystone.sysnet.local/keystone # sql access credentials {username:111,dbname:keystone,hostname:keystone.sysnet.local,dbname:keystone}
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[federation]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[ldap]
[matchmaker_redis]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
[policy]
[profiler]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[signing]
[token]
provider = fernet # use fernet token mechanish from avaliable uuid, and pki
[tokenless_auth]
[trust]
[unified_limit]
[ssl]
[eventlet_server_ssl]

keystone-manage db_sync keystone # init tables inside mysql 
# those setting require in case of db migration 
keystone-manage db_sync keystone --expand # create already migrated db scheamas
keystone-manage db_sync keystone --migrate # perform data migration
keystone-manage db_sync keystone --contract # erase old data

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone # set up the fernet token repo

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone # set up credentional based key for fernet repo 

keystone-manage bootstrap --bootstrap-password 111 --bootstrap-admin-url https://keystone.sysnet.local:35357/v3/ --bootstrap-internal-url https://keystone.sysnet.local:5000/v3/ --bootstrap-public-url https://keystone.sysnet.local:5000/v3/ --bootstrap-region-id yerevan # fill db tables according to your enviroment, use https instead of http if you wish to set up ssl/tls encryption.

rm /etc/httpd/conf.d/welcome.conf # rm apache default page
cat /etc/httpd/conf.d/wsgi-keystone.conf 
# example config
Listen 5000
Listen 35357

<VirtualHost *:5000>
    SSLEngine on # enable ssl 
    SSLCertificateFile    /etc/httpd/ssl/keystone.sysnet.local/keystone.sysnet.local.crt # point to crt (644)
    SSLCertificateKeyFile /etc/httpd/ssl/keystone.sysnet.local/keystone.sysnet.local.key # to key (600)
    SSLCACertificateFile  /etc/httpd/ssl/ca.pem # to trusted ca, make sure curl also recognize the default ca (644)



# mod_proxy: The main proxy module for Apache that manages connections and redirects them.
# modproxyhttp: This module implements the proxy features for HTTP and HTTPS protocols.
# modproxyftp: This module does the same but for FTP protocol.
# modproxyconnect: This one is used for SSL tunnelling.
# modproxyajp: Used for working with the AJP protocol.
# modproxywstunnel: Used for working with web-sockets (i.e. WS and WSS).
# modproxybalancer: Used for clustering and load-balancing.
# mod_cache: Used for caching.
# mod_headers: Used for managing HTTP headers.
# mod_deflate: Used for compression.

    SSLCACertificatePath    /etc/httpd/ssl/ # trusted ca folder
    SSLCARevocationPath     /etc/httpd/ssl/ # same
    SSLVerifyClient         optional # optional: the client may present a valid Certificate or require: the client has to present a valid Certificate
    SSLVerifyDepth          10 # ca certificate depts or nb of intermediate certificates for you ca.
    SSLProtocol             all -SSLv2 # all except ssl version 2
    SSLCipherSuite          ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW # define secure chiper suit
    SSLOptions              +StdEnvVars +ExportCertData 

    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    # WSGIDaemonProcess name [ options ]

    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public # aliace web root to pre build binary 
    WSGIApplicationGroup %{GLOBAL} # deleagete to run as group of process names keystone
    WSGIPassAuthorization On#  to be set to On if the WSGI application was to handle authorisation rather than Apache doing it.
    LimitRequestBody 114688 # body size in bytes

    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/httpd/keystone.log
    CustomLog /var/log/httpd/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    SSLEngine on
    SSLCertificateFile    /etc/httpd/ssl/keystone.sysnet.local/keystone.sysnet.local.crt
    SSLCertificateKeyFile /etc/httpd/ssl/keystone.sysnet.local/keystone.sysnet.local.key
    SSLCACertificateFile  /etc/httpd/ssl/ca.pem

    SSLCACertificatePath    /etc/httpd/ssl/
    SSLCARevocationPath     /etc/httpd/ssl/
    SSLVerifyClient         optional
    SSLVerifyDepth          10
    SSLProtocol             all -SSLv2
    SSLCipherSuite          ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW
    SSLOptions              +StdEnvVars +ExportCertData

    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LimitRequestBody 114688
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/httpd/keystone.log
    CustomLog /var/log/httpd/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>


# alias identity to keyston public handler
Alias /identity /usr/bin/keystone-wsgi-public
<Location /identity>
    SetHandler wsgi-script # /identity will be hadnled by wsgi-script 
    Options +ExecCGI # execute throug common gateway interface, The Options directive controls which server features are available in a particular directory.

    WSGIProcessGroup keystone-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
</Location>

Alias /identity_admin /usr/bin/keystone-wsgi-admin
<Location /identity_admin>
    SetHandler wsgi-script
    Options +ExecCGI

    WSGIProcessGroup keystone-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
</Location>


# export env vars for openstack client bin

export OS_USERNAME=admin
export OS_PASSWORD=111
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_REGION_NAME=yerevan
export OS_AUTH_URL=https://keystone.sysnet.local:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_CACERT=/etc/httpd/ssl/ca.pem

