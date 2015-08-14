cstruct dhcp {
  uint8_t op;
  uint8_t htype;
  uint8_t hlen;
  uint8_t hops;
  uint32_t xid;
  uint16_t secs;
  uint16_t flags;
  uint32_t ciaddr;
  uint32_t yiaddr;
  uint32_t siaddr;
  uint32_t giaddr;
  uint8_t chaddr[16];
  uint8_t sname[64];
  uint8_t file[128];
  uint32_t cookie
} as big_endian

cenum mode {
  BootRequest = 1;
  BootReply
} as uint8_t

type dhcp_packet = {
  xid: int32;
  flags: int;
  ciaddr: Ipaddr.V4.t;
  yiaddr: Ipaddr.V4.t;
  giaddr: Ipaddr.V4.t;
  chaddr: string;
  options: Dhcpv4_option.Packet.p;
}

let dhcp_packet_of_cstruct buf = 
  let ciaddr = Ipaddr.V4.of_int32 (get_dhcp_ciaddr buf) in
  let yiaddr = Ipaddr.V4.of_int32 (get_dhcp_yiaddr buf) in
  let giaddr = Ipaddr.V4.of_int32 (get_dhcp_giaddr buf) in
  let xid = get_dhcp_xid buf in
  let of_byte x =
    Printf.sprintf "%02x" (Char.code x) in
  let chaddr_to_string x =
    let chaddr_size = (Bytes.length x) in
    let dst_buffer = (Bytes.make (chaddr_size * 2) '\000') in
      for i = 0 to (chaddr_size - 1) do
        let thischar = of_byte x.[i] in
          Bytes.set dst_buffer (i*2) (Bytes.get thischar 0);
          Bytes.set dst_buffer ((i*2)+1) (Bytes.get thischar 1)
      done;
    dst_buffer
  in
  let chaddr = (chaddr_to_string) (copy_dhcp_chaddr buf) in
  let flags = get_dhcp_flags buf in
  let options_raw = Cstruct.(copy buf sizeof_dhcp (len buf - sizeof_dhcp)) in
  let options = Dhcpv4_option.Packet.of_bytes options_raw in
  {xid;flags;ciaddr;yiaddr;giaddr;chaddr;options};;

let dhcp_packet_constructor ~op ~xid ~secs ~flags ~ciaddr ~yiaddr ~siaddr ~giaddr ~chaddr ~options ~dest =
  let options = Dhcpv4_option.Packet.to_bytes options in
  let options_len = Bytes.length options in
  let buf = Io_page.(to_cstruct (get 1)) in
  set_dhcp_op buf (mode_to_int op);
  set_dhcp_htype buf 1; (*Default to ethernet, TODO: implement other hardware types*)
  set_dhcp_hlen buf 6; (*Hardware address length, defaulted to ethernet*)
  set_dhcp_hops buf 0; (*Hops is used by relay agents, clients/server always initialise it to 0*)
  set_dhcp_xid buf xid; (*Transaction id, generated by client*)
  set_dhcp_secs buf 0; 
  set_dhcp_flags buf flags; (*Flags field. Server always sends back the flags received from the client*)
  set_dhcp_ciaddr buf (Ipaddr.V4.to_int32 ciaddr);
  set_dhcp_yiaddr buf (Ipaddr.V4.to_int32 yiaddr);
  set_dhcp_siaddr buf (Ipaddr.V4.to_int32 siaddr);
  set_dhcp_giaddr buf (Ipaddr.V4.to_int32 giaddr);
  (* TODO add a pad/fill function in cstruct *)
  set_dhcp_chaddr chaddr 0 buf; (*Client hardware address. TODO: ensure this is being passed correctly...*)
  set_dhcp_sname (Bytes.make 64 '\000') 0 buf; (*server name, TODO: find out how to set this in dhcpd*)
  set_dhcp_file (Bytes.make 128 '\000') 0 buf;
  set_dhcp_cookie buf 0x63825363l;
  Cstruct.blit_from_string options 0 buf sizeof_dhcp options_len;
  Cstruct.set_len buf (sizeof_dhcp + options_len),dest ;;