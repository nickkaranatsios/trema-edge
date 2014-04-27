module LinkHelper
  def update_flow_stats link, msg, rx
    if rx
      link.rx_byte_count += msg.byte_count
    else
      link.tx_byte_count += msg.byte_count
      link.tx_byte_count += link.packet_out_tx_byte_count
    end
  end

  def update_host_stats rx_bytes, tx_bytes, link
    link.rx_byte_count += rx_bytes
    link.tx_byte_count += tx_bytes
  end
end

