# RULES

if(node[:omnibus_updater][:version].nil? || node[:omnibus_updater][:version_search])
  require 'open-uri'
  require 'rexml/document'
  pkgs_doc = REXML::Document.new(open(node[:omnibus_updater][:base_uri]))
  pkgs_avail = pkgs_doc.elements.to_a('//Contents//Key').map(&:text).find_all do |f|
    !f.scan(/\.(rpm|deb)$/).empty?
  end
else
  if(node[:omnibus_updater][:version].include?('-'))
    node.default[:omnibus_updater][:full_version] = node[:omnibus_updater][:version]
  else
    node.default[:omnibus_updater][:full_version] = "#{node[:omnibus_updater][:version]}-1"
  end
end

platform_name = node.platform
platform_majorversion = ""
case node.platform_family
when 'debian'
  if(node.platform == 'ubuntu')
    platform_version = case node.platform_version
    when '10.10', '10.04'
       platform_majorversion << '10.04'
      '10.04'
    when '12.10', '12.04', '11.10', '11.04'
       platform_majorversion << '11.04'
      '11.04'
    else
      raise 'Unsupported ubuntu version for deb packaged omnibus'
    end
  else
    platform_version = case pv = node.platform_version.split('.').first
    when '6', '5'
      platform_majorversion << '6'
      '6.0.5'
    else
      platform_majorversion << pv
      pv
    end
  end
when 'fedora', 'rhel'
  platform_version = node.platform_version.split('.').first
  platform_name = 'el'
  platform_majorversion << '6'
else
  platform_version = node.platform_version
end

if(node[:omnibus_updater][:install_via])
  install_via = node[:omnibus_updater][:install_via]
else
  install_via = case node.platform_family
  when 'debian'
    'deb'
  when 'fedora', 'rhel', 'centos'
    'rpm'
  else
    raise 'Unsupported omnibus install method requested'
  end
end
case install_via
when 'deb'
  if(pkgs_avail)
    path_name = pkgs_avail.find_all{ |path|
      ver = node[:omnibus_updater][:version] || '.'
      path.include?('.deb') && path.include?(platform_name) && 
      path.include?(platform_version) && path.include?(node.kernel.machine) &&
      path.include?(ver)
    }.sort.last
  else
    kernel_name = ""
    file_name = "chef_#{node[:omnibus_updater][:full_version]}.#{platform_name}.#{platform_version}_"
    if(node.kernel.machine.include?('64'))
      file_name << 'amd64'
      kernel_name << 'x86_64'
    else
      file_name << 'i386'
      kernel_name << 'i686'
    end
    file_name << '.deb'
  end
when 'rpm'
  if(pkgs_avail)
    path_name = pkgs_avail.find_all{ |path|
      ver = node[:omnibus_updater][:version] || '.'
      path.include?('.rpm') && path.include?(platform_name) && 
      path.include?(platform_version) && path.include?(node.kernel.machine) &&
      path.include?(ver)
    }.sort.last
  else
    file_name = "chef-#{node[:omnibus_updater][:full_version]}.#{platform_name}#{platform_version}.#{node.kernel.machine}.rpm"
  end
end

remote_omnibus_file = if(path_name)
    File.join(node[:omnibus_updater][:base_uri], path_name)
  else
    File.join(
      node[:omnibus_updater][:base_uri],
      platform_name,
      platform_majorversion,
      kernel_name,
      file_name
    )
  end

unless(remote_omnibus_file == node[:omnibus_updater][:full_uri])
  node.override[:omnibus_updater][:full_uri] = remote_omnibus_file
  Chef::Log.info "Omnibus remote file location: #{remote_omnibus_file}"
end

unless(node[:omnibus_updater][:full_version])
  node.default[:omnibus_updater][:version] = remote_omnibus_file.scan(/chef[_-](\d+\.\d+\.\d+)/).flatten.first
  if(node[:omnibus_updater][:version].include?('-'))
    node.default[:omnibus_updater][:full_version] = node[:omnibus_updater][:version]
  else
    node.default[:omnibus_updater][:full_version] = "#{node[:omnibus_updater][:version]}-1"
  end
end

