require 'net/http'

# TODO: KERB This class should be replaced by an out of proc service that:
#   a) may run as a different user with the correct LDAP credentials / configuration
#   b) can cache lookups
#   c) can be restarted / cache flushed independently from puppet/apache/nginx state
#   d) can be replaced / customized

class Puppet::Network::HTTP::RackLDAP

  def ldapSimple
    Net::LDAP.new(
      :host => Puppet[:remote_user_ldap_server],
      :port => Puppet[:remote_user_ldap_port],
      # TODO: KERB provide support for encrypted connections
      #:port => 636,
      #:encryption => :simple_tls,
      :auth => {
        :method => :simple,
        :username => Puppet[:remote_user_ldap_evil_horrible_hack_username],
        :password => Puppet[:remote_user_ldap_evil_horrible_hack_password],
      })
  end

  def initialize
    require 'net/ldap'
    @ldap = ldapSimple
  rescue LoadError
  end

  def lookupHostname(remote_user)
    return nil if @ldap.nil?

    # account is everything before @, if any
    remote_account = remote_user[/^[^@]*/]

    args = {
      :filter => Net::LDAP::Filter.eq("sAMAccountName", remote_account),
      :base => "dc=puppet,dc=corp",
      :attributes => ['dNSHostName']
    }
    entries = @ldap.search(args)

    if entries == nil
      Puppet.warning "lookup failed for account '#{remote_account}': #{ldap.get_operation_result}"
      return nil
    end
    if entries.length > 1
      Puppet.warning "found multiple DNs for account '#{remote_account}'"
      return nil
    end
    Puppet.warning "entries: #{entries}"
    return nil if entries.length == 0
    hostnames = entries[0].dnshostname
    return nil if not hostnames or hostnames.length == 0
    # arbitrarily choose first
    # TODO: KERB if we get multiple dNSHostName's maybe we should look for a unique match with the account name?
    hostname = hostnames[0]
    return nil if hostname.to_s == ''
    hostname
  end

end

