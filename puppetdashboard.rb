#!/usr/bin/env ruby

require 'optparse'
require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'date'

def parse_arguments(args)

  orig_args = args.dup

  # Set allow commands
  date_cmds = [:created_at, :reported_at, :updated_at] 
  node_cmds = [:status] + date_cmds
  sum_cmds = [
    :nodes_unchanged,
    :nodes_failed,
    :nodes_changed,
    :nodes_unresponsive,
    :nodes_pending,
    :nodes_unreported,
    :nodes_all
  ]
  cmds = [:discovery, :zabbix_sender] + node_cmds + sum_cmds

  # Set defaults
  options = {
    :verbose => false,
    :ssl_verify => true,
    :dashboard_url => URI.parse('http://127.0.0.1/puppet-dashboard'),
    :date_cmds => date_cmds,
    :sum_cmds => sum_cmds,
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename(__FILE__)} [options] -c [#{cmds.join('|')}]"

    opts.on('-c','--command CMD', "Command to execute") do |cmd|
      cmd = cmd.to_sym
      if not cmds.include? cmd.to_sym then
        STDERR.puts "Unknown command '#{cmd}'"
        exit 1
      end 
      options[:command] = cmd.to_sym if cmd.to_sym 
    end

    # verbosity flag
    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options[:verbose] = v
    end

    # no ssl verify flag
    opts.on("-S", "--no-ssl-verify", "Disable ssl verify") do |s|
      options[:ssl_verify] = false
    end

    # nodename 
    opts.on("-n", "--nodename NAME", "Give node hostname for cmds [#{node_cmds.join('|')}]") do |node_name|
      options[:node_name] = node_name
    end

    # dashboard base url
    opts.on("-u", "--url URL", "Give dashboard base url") do |url|
      begin
        uri = URI.parse url
        raise 'No http(s) url' if uri.scheme != 'http' and uri.scheme != 'https' 
        options[:dashboard_url] = uri
      rescue Exception => e
        STDERR.puts "wrong url given: #{e.message}"
        exit 1
      end
    end

    # show help
    opts.on("-h", "--help", "Show this help") do |v|
      STDERR.puts opts
      exit
    end

  end.parse!(args)

  if options[:verbose] then
    STDERR.puts "arguments given: #{orig_args}"
    STDERR.puts "options #{options}"
  end

  # command is required
  if options[:command].nil? then
    STDERR.puts 'No command given'
    exit 1
  end

  # node_name is required for node_cmds
  if node_cmds.include?(options[:command]) and options[:node_name].nil? then
    STDERR.puts 'No nodename given'
    exit 1
  end
  return options
end

def fetch_url(path, options)
  begin
    uri = URI.parse(File.join(options[:dashboard_url].to_s, path))
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      if not options[:ssl_verify] then
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end
    data = http.get(uri.request_uri)
    return JSON.parse data.body
  rescue Exception => e
    STDERR.puts "unable to fetch url '#{uri.to_s}': #{e.message}"
    exit 1
  end
end

# Show node stats
def node_stats(data, nodename, value, date_cmds)
  value_s = value.to_s
  data.each do |node|
    if node['name'] == nodename then
      if node.keys.include? value_s
        if date_cmds.include? value
          if node[value_s].nil?
            STDERR.puts 'Not reported yet'
            exit 1
          end
          return DateTime.strptime(node[value_s]).strftime('%s')
        else
          return 'unreported' if value == :status and node[value_s].nil?
          return node[value_s]
        end
      end
    end
  end

  STDERR.puts "No node with name '#{nodename}' found"
  exit 2
end

# sum up nodes status
def sum_nodes_stats(data)
  # unresponsive after 4 hours
  unresponsive_diff = 4*60*60

  # Count hash
  count = {
    :nodes_unchanged => 0,
    :nodes_failed => 0,
    :nodes_changed => 0,
    :nodes_unresponsive => 0,
    :nodes_pending => 0,
    :nodes_unreported => 0,
    :nodes_all => data.length
  }

  # Sum up nodes
  data.each do |node|
    diff = DateTime.now - DateTime.parse(node['updated_at'])
    if node['status'].nil?
      count[:nodes_unreported] +=1
    elsif diff > unresponsive_diff
      count[:nodes_unresponsive] +=1
    else
      count["nodes_#{node['status']}".to_sym] += 1
    end
  end

  count
end

# Generate discover output
def show_discover(data)
  nodes = {
    :data => []
  }
  data.each do |node|
    nodes[:data] += [{'{#NODE_NAME}' => node['name']}]
  end
  nodes
end

# Get stdin output for zabbix sender
def show_zabbix_sender(data)
  lines = []

  sum_nodes_stats(data).each do |key, value|
    key=key.to_s.sub!('_','.')
    lines << ["puppetdashboard.#{key}", Time.now.to_i, value]
  end

  data.each do |node|
    report_time = node['reported_at']
    next if report_time.nil?
    report_time = DateTime.strptime(report_time).strftime('%s').to_i
    lines << ["puppetdashboard.node.status[#{node['name']}]", report_time, node['status']]
    lines << ["puppetdashboard.node.reported_at[#{node['name']}]", Time.now.to_i, report_time]
  end

  # Get longest key
  keys_max = lines.map{|line| line[0].length}.max

  # Output lines
  lines.map! do |line|
    sprintf("- %-#{keys_max+1}s %d %s", *line)
  end
  lines.join("\n")
end

def main
  # get options
  options = parse_arguments(ARGV)
  data = fetch_url('nodes.json', options)

  if options[:command] == :discovery then
    puts JSON.generate show_discover data
  elsif options[:sum_cmds].include? options[:command]
    puts sum_nodes_stats(data)[options[:command]]
  elsif options[:command] == :zabbix_sender
    puts show_zabbix_sender(data)
  else
    puts node_stats(data, options[:node_name], options[:command], options[:date_cmds])
  end
end

main
