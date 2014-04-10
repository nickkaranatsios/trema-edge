class PortArray < Array
  def find_by_name name
    select { | p | p.name ==  name }
  end
end
