/*
 * Copyright (C) 2014 NEC Corporation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2, as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */


#include "trema.h"
#include "ruby.h"
#include "action-common.h"
#include "hash-util.h"


buffer *
pack_port_mod( VALUE options ) {
  uint32_t xid = get_transaction_id();
  VALUE r_xid = HASH_REF( options, transaction_id );
  if ( !NIL_P( r_xid ) ) {
    xid = NUM2UINT( r_xid );
  }

  uint32_t port_no = 0;
  VALUE r_port_no = HASH_REF( options, port_no );
  if ( !NIL_P( r_port_no ) ) {
    port_no = ( uint32_t ) NUM2UINT( r_port_no );
  }

  uint8_t hw_addr[ OFP_ETH_ALEN ];
  VALUE r_hw_addr = HASH_REF( options, hw_addr );
  if ( !NIL_P( r_hw_addr ) ) {
    dl_addr_to_a( r_hw_addr, hw_addr );
  }

  uint32_t config = 0;
  VALUE r_config = HASH_REF( options, config );
  if ( !NIL_P( r_config ) ) {
    config = ( uint32_t ) NUM2UINT( r_config );
  }

  uint32_t mask = 0;
  VALUE r_mask = HASH_REF( options, mask );
  if ( !NIL_P( r_mask ) ) {
    mask = ( uint32_t ) NUM2UINT( r_mask );
  }

  uint32_t advertise = 0;
  VALUE r_advertise = HASH_REF( options, advertise );
  if ( !NIL_P( r_advertise ) ) {
    r_advertise = ( uint32_t ) NUM2UINT( r_advertise );
  }

  buffer *port_mod = create_port_mod( xid,
                                      port_no,
                                      hw_addr,
                                      config,
                                      mask,
                                      advertise );
  return port_mod;
}


/*
 * Local variables:
 * c-basic-offset: 2
 * indent-tabs-mode: nil
 * End:
 */
