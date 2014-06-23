# Compute skus using a simple algorithm.
# Map manufacturer to 3 character manfacturer code.
# Append board serial if available, else system serial.
# @param [String] vendor - manufacturor of the asset for which we should compute the SKU
# @param [String] serial - serial number of the chassis for the asset for which we should compute the SKU
# @param [String] board_serial - serial number of the motherboard for the asset for which we should compute the SKU
def compute_sku( vendor, serial, board_serial )

  # Sanitize params 
  strip_pattern = /[^-^:\p{Alnum}]/
  serial        = serial.gsub(strip_pattern,'')
  vendor        = vendor.gsub(strip_pattern,'')
  board_serial  = board_serial.gsub(strip_pattern,'')

  if not board_serial.empty? 
    serial = board_serial
  end

  case vendor 
    when "Dell Inc."
      sku="DEL"
    when "Supermicro"
      sku="SPM"
    else
      sku="UKN" # unknown manufacturer
  end
 
  sku="#{sku}-#{serial}"
  return sku
end
