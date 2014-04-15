#
# Network link between hosts and switches of Trema network DSL.
#
# Copyright (C) 2008-2013 NEC Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#


module Trema
  module DSL
    class Link
      attr_reader :peers
      attr_reader :cost
      attr_reader :bwidth


      # cost value for link
      def initialize peer0, peer1, *extra_params
        @peers = [ peer0, peer1 ]
        @cost = 0
        unless extra_params.empty?
          @cost = extra_params.first
          if extra_params.length > 1
            @bwidth = extra_params.last
          end
        end
      end
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
