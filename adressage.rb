##########################
##########################
# ------------------------
# COPYRIGHT : Naël EMBARKI
# ------------------------
##########################
##########################
require 'ipaddr'

RED    = "\e[1;31m"
YELLOW = "\e[1;33m"
GREEN  = "\e[1;32m"
BLUE   = "\e[1;34m"
PINK   = "\e[1;35m"
CYAN   = "\e[1;36m"
NC     = "\e[0m"

def bin(int)
    int.to_s(2)
end

def bin_8(int)
    format('%08b', int)
end

def hexa_to_bin(octets)
    octets = octets.gsub(/^0x/, '')
    octets.scan(/../).map { |octet| format('%08b', octet.to_i(16)) }.join(' ')
end

def bin_to_hexa(bin_str)
    "0x" + bin_str.scan(/.{8}/).map { |binary| format('%02X', binary.to_i(2)) }.join('')
end  
  
def mask_to_octets(mask)
    binary_mask = (0xFFFFFFFF << (32 - mask)) & 0xFFFFFFFF
    [24, 16, 8, 0].map { |shift| (binary_mask >> shift) & 255 }.join('.')
end

def octets_to_mask(octets)
    binary_mask = octets.split('.').map(&:to_i).reduce(0) { |acc, octet| (acc << 8) + octet }
    bin(binary_mask).count('1').to_i
end

def hexa_to_ip(hex)
    hex = hex.gsub(/^0x/, '')
    ip_int = hex.to_i(16)
    [24, 16, 8, 0].map { |shift| (ip_int >> shift) & 255 }.join('.')
end

def ip_to_hexa(ip)
    "0x" + ip.split('.').map(&:to_i).inject(0) { |acc, part| (acc << 8) + part }.to_s(16).upcase
end

def network_address(ip_address, mask)
    ip = IPAddr.new("#{ip_address}/#{mask}")
    network_ip = ip.mask(mask)
    network_ip.to_s
end

def number_subnets_by_mask(mask, subnet_class)
    tab = {'A' => 2**24, 'B' => 2**16, 'C' => 2**8}
    length = tab[subnet_class]
    return length.nil? ? nil : (2**mask)/length
end

def length_subnet_by_mask(mask)
    2**(32 - mask)
end

def hosts_by_subnet(mask)
    length_subnet_by_mask(mask) - 2
end

def broadcast_address(network, mask)
    network = network_address(network, mask)
    mask_octets = mask_to_octets(mask).split('.').map(&:to_i)
    network_octets = network.split('.').map(&:to_i)
    broadcast_octets = network_octets.each_with_index.map do |octet, index|
      octet | ~mask_octets[index] & 0xFF
    end
    broadcast_octets.join('.')
end

def adressage(base_ip, num_subnets, subnet_size, new_prefix_length)
    subnets = []
    start_ip = base_ip.to_i
    num_subnets.times do
        subnet_start = IPAddr.new(start_ip, Socket::AF_INET)
        subnet_end = IPAddr.new(start_ip + subnet_size - 1, Socket::AF_INET)
        start_ip += subnet_size
        network_address = subnet_start
        broadcast_address = subnet_end
        assignable_range_start = IPAddr.new(network_address.to_i + 1, Socket::AF_INET)
        assignable_range_end = IPAddr.new(broadcast_address.to_i - 1, Socket::AF_INET)
        subnets << {
            network_address: network_address.to_s,
            mask: new_prefix_length,
            assignable_range: "#{assignable_range_start} - #{assignable_range_end}",
            broadcast_address: broadcast_address.to_s
        }
    end
    subnets
end

def FLSM(network, mask, num_subnets, print=true)
    if network.is_a?(Array)
        tab = []
        network.each do |subnetwork|
            res = FLSM(subnetwork, mask, num_subnets, print)
            tab.concat(res) unless res.nil?
        end
        return print ? nil : tab
    end
    network = network_address(network, mask)
    base_ip = IPAddr.new("#{network}/#{mask}")
    original_prefix_length = base_ip.prefix
    new_prefix_length = original_prefix_length + Math.log2(num_subnets).ceil
    puts "Nouveau masque : #{YELLOW}2^(32 - #{mask})/#{num_subnets}" +
    " = 2^(#{32 - mask})/#{num_subnets} = #{GREEN}#{mask_to_octets(new_prefix_length)} #{PINK}(/#{new_prefix_length})#{NC}"
    if hosts_by_subnet(new_prefix_length) < 1
        puts "#{RED}Erreur, il doit y avoir au moins un hôte par sous-réseau.#{NC}"
        return nil
    end
    subnet_size = length_subnet_by_mask(new_prefix_length)
    puts "Taille de chaque sous-réseau : #{YELLOW}2^(32 - #{new_prefix_length}) = #{GREEN}2^(#{32 - new_prefix_length}) = #{PINK}#{subnet_size}#{NC}"
    subnets = adressage(base_ip, num_subnets, subnet_size, new_prefix_length)
    if print
        print_subnet_table(subnets)
        return nil
    end
    subnets
end

def VLSM(network, mask, subnets, print=true)
    base_ip = IPAddr.new("#{network}/#{mask}")
    start_ip = base_ip.to_i
    subnets.sort!
    vlsm_subnets = []
    subnets.reverse_each do |subnet|
        needed_hosts = subnet + 2
        new_prefix_length = 32 - Math.log2(needed_hosts).ceil
        subnet_size = length_subnet_by_mask(new_prefix_length)
        if needed_hosts > subnet_size
            puts "#{RED}Erreur: le sous-réseau requiert plus d'adresses que disponible.#{NC}"
            return nil
        end
        result = adressage(IPAddr.new(start_ip, Socket::AF_INET), 1, subnet_size, new_prefix_length)
        start_ip += subnet_size
        vlsm_subnets.concat(result)
    end
    if print
        print_subnet_table(vlsm_subnets)
        return nil
    end
    vlsm_subnets
end

def print_subnet_table(subnets)
    if subnets.nil?
        puts "#{RED}Terminaison.#{NC}"
        return nil
    end
    puts "#{PINK}Sous-réseau traité\tAdresse Réseau\tMasque\tPlage d'Adresses Attribuables\tAdresse de Diffusion"
    puts "-" * 110
    puts "#{NC}"
    count = 1
    subnets.each do |subnet|
        puts "#{PINK}#{count}\t\t#{GREEN}#{subnet[:network_address]}\t\t#{YELLOW}/#{subnet[:mask]}\t\t#{RED}#{subnet[:assignable_range]}\t\t#{CYAN}#{subnet[:broadcast_address]}#{NC}"
        count += 1
    end
    puts "#{PINK}-#{NC}" * 110
    return nil
end
