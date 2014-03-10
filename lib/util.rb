# Compute skus using a simple algorithm.
#    Map manufacturer to 3 character manfacturer code.
#    Append board serial if available, else system serial.
def compute_sku( params )

  strip_pattern = /[^-^:\p{Alnum}]/
  mac           = params["mac"].gsub(strip_pattern,'')
  serial        = params["serial"].gsub(strip_pattern,'')
  product       = params["product"].gsub(strip_pattern,'')
  vendor        = params["manufacturer"].gsub(strip_pattern,'')
  board_serial  = params["board-serial"].gsub(strip_pattern,'')
  board_product = params["board-product"].gsub(strip_pattern,'')

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


