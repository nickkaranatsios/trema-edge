$(function($, window) {
  $.ajaxSetup({
    dataType: 'text',
    error: function(xhr, status, error) {
      info('Error! ' +  ( error ? error : xhr.status ));
    }
  });

  function info(text) {
    $('#info-text').text(text);
  }

  var stage, Node = window.Node, Segment = window.Segment;

  var NODE_DIMENSIONS = {
    w: 50,
    h: 50
  };
  var h_nodes = {}
  var bwidth = $("#bandwidth");
  var link_bwidth = $("#link_bandwidth");
  var hostFields = $([]).add(bwidth), tips = $(".validateTips");
  var linkFields = $([]).add(link_bwidth), tips = $(".validateTips");

  /*
  $(document).ready(function() {
    var timer = setInterval(update_stats, 30000);

    function update_stats() {
      window.console.log("periodic update stats is called");
      for (var key in h_nodes) {
        window.console.log(key);
        update_node_info(h_nodes[key], key);
      }
    }
  });
  */
  

  $.getJSON('/topology', function(data) {
    var nodes = data['topo-keys']
    var start_x = 200, start_y = 200

    stage = $('#stage');
    $(nodes).each(function(i, item) {
      window.console.log(item);
      window.console.log(data[item]);
      h_nodes[item] = new Node({
        type: 'node',
        title: item,
        stage: stage,
        w: NODE_DIMENSIONS.w,
        h: NODE_DIMENSIONS.h,
        x: start_x,
        y: start_y,
        events: {
          click: function() {
            // window.console.log(this);
            update_node_info(this, item);
          }
        }
      }).attach();
      start_x += 100;
    });
    $(nodes).each(function(i, item) {
      var links = jQuery.parseJSON(data[item]);
      $(links).each(function(j, link) {
        from = link['from'];
        to = link['to'];
        if ( from in h_nodes && to in h_nodes ) {
          new Segment({
            type: 'segment',
            w: 0,
            h: 5,
            stage: stage,
            origin: h_nodes[from],
            destination: h_nodes[to],
            events: {
              dblclick: function() {
                this.el.css('background-color', 'rgb(204,53,178)');
                window.console.log(this.canvas.el.css("background-color"));
                window.console.log("segment clicked for " + this.origin.title + "  " + this.destination.title);
                request_link_info(this.origin.title, this.destination.title);
              }
            }
          }).attach();
        } else {
          host_node = new Node({
            type: 'host',
            title: to,
            stage: stage,
            w: NODE_DIMENSIONS.w / 2,
            h: NODE_DIMENSIONS.h / 2,
            x: start_x,
            y: start_y,
            events: {
              dblclick: function() {
                window.console.log(this);
                request_host_info(this, to);
              }
            }
          }).attach();
          start_x += 100;
          new Segment({
            type: 'segment',
            w: 0,
            h: 5,
            stage: stage,
            origin: h_nodes[from],
            destination: host_node
          }).attach();
        }
      });
    });
  });

  function update_node_info(node, key) {
    $.ajax({
      type: 'PUT',
      dataType: 'json',
      url: '/topology/' + key,
      success: function(data) {
        display_node_info(data);
        window.console.log("event data ")
        window.console.log(node);
        window.console.log("position ")
        window.console.log(node.el.position());
        var node_data="";
        $(node.segments).each(function(i, seg) {
          dst_node = seg.destination;
          if (node.title == dst_node.title) {
            return;
          }
          pkts = pkt_info(data, dst_node.title);
          node_data += node.title + "=>" + dst_node.title + ":RX bytes:"; 
          res_rx = unit_of(pkts['rxbytes']);
          res_tx = unit_of(pkts['txbytes']);
          edge = (/^e/).test(node.title);
          core = (/^c/).test(dst_node.title);
          if (edge && core) {
            capacity = Math.pow(10, 6 ) * pkts['bwidth'];
            bwidth = capacity - Math.max(pkts['rxbytes'], pkts['txbytes']);
            used_bwidth = capacity - bwidth;
            window.console.log("used bwidth" + used_bwidth);
            var color = 'red';
            if (used_bwidth >= 0 && used_bwidth < capacity / 3.0) {
              color = '#bae4b3';
            }
            else if (used_bwidth >= capacity / 3.0 && used_bwidth >= capacity / 2.0) {
              color = '#ffa500';
            }
            this.el.css('background-color', color);
          }
          node_data += pkts['rxbytes'] + " ("+ res_rx['num_to_unit'] + " " + res_rx['unit'] + ") TX bytes: " + pkts['txbytes'] + " ("+ res_tx['num_to_unit'] + " " + res_tx['unit'] + ")</br>";
        });
        h5_el = node.el.find('h5');
        if (h5_el.length != 0 ) {
          h5_el.html("");
          h5_el.html(node_data);
        }
        else {
          node.el.append('<h5>' + node_data + '</h5>');
        }
        window.console.log(data);
      }
    });
  }

  function request_host_info(host, name) {
    host_info = getPutHost(host.title);
  }

  function request_link_info(from, to) {
    link_info = getPutLink(from, to);
  }

  function pkt_info(data, to) {
    var pkts = {};
    var links = jQuery.parseJSON(data);
    $(links).each(function(i, link) {
      if (link['to'] == to) {
        pkts['rxbytes'] = link['rx_byte_count'];
        pkts['txbytes'] = link['tx_byte_count'];
        pkts['bwidth'] = link['bwidth'];
      }
    });
    return pkts;
  }

  function link_cost(data, to) {
  var tips = $( ".validateTips" );
    var str = ""
    var links = jQuery.parseJSON(data);
    $(links).each(function(i, link) {
      if (link['to'] == to) {
        str = link['cost'];
      }
    });
    return str;
  }


  function display_node_info(data) {
    window.console.log(Node);
  }

  function updateTips(t) {
      tips.text(t).addClass("ui-state-highlight");
      setTimeout(function() {
        tips.removeClass("ui-state-highlight", 1500);
      }, 500);
  }

  function checkType(o) {
    var value = o.val();
    if ($.isNumeric(value) === false) {
      o.addClass("ui-state-error");
      updateTips("Bandwidth entered must be a numeric decimal/float number");
      return false;
    }
    return true;
  }
  

  $('#host-dialog-form').dialog({
    autoOpen: false,
    height: 260,
    width: 350,
    modal: true,
    buttons: {
      "Assign": function() {
         hostFields.removeClass("ui-state-error");
         var bValid = true;
         bValid = checkType(bwidth);
         if (bValid) {
           var bwidthVal = bwidth.val();
           var hostName = $(this).data('host_name');
           putBwidth(hostName, bwidthVal);
           $(this).dialog("close");
         }
      },
      Cancel:function() {
        $(this).dialog("close");
      }
    },
    close: function() {
      hostFields.val("").removeClass("ui-state-error");
    }
  });

  $('#link-dialog-form').dialog({
    autoOpen: false,
    height: 260,
    width: 550,
    modal: true,
    buttons: {
      "Assign": function() {
         linkFields.removeClass("ui-state-error");
         var bValid = true;
         bValid = checkType(link_bwidth);
         if (bValid) {
           var bwidthVal = link_bwidth.val();
           var from = $(this).data('from');
           var to = $(this).data('to');
           putLinkBwidth(from, to, bwidthVal);
           $(this).dialog("close");
         }
      },
      Cancel:function() {
        $(this).dialog("close");
      }
    },
    close: function() {
      linkFields.val("").removeClass("ui-state-error");
    }
  });

  function putBwidth(host, bwidth) {
    $.ajax({
      type: 'PUT',
      dataType: 'json',
      url: '/hosts/' + host + '/assign/' + bwidth,
      success: function(data) {
        // TODO change the bwidth display info
        window.console.log("put host bwidth request successfully");
      }
    });
  }

  function putLinkBwidth(from, to, bwidth) {
    $.ajax({
      type: 'PUT',
      dataType: 'json',
      url: '/links/from/' + from + '/to/' + to + '/assign/' + bwidth,
      success: function(data) {
        window.console.log("put link bwidth request successfully");
      }
    });
  }

  function getPutHost(key) {
    $.ajax({
      type: 'GET',
      dataType: 'json',
      url: '/hosts/' + key,
      success: function(data) {
        host_info = jQuery.parseJSON(data);
        $('#host-dialog-form').dialog({title: "Assign Bandwidth for " + key});
        $("#bandwidth").val(5.0);
        if (host_info['bwidth']) {
          var cur_val = parseFloat(host_info['bwidth']);
          window.console.log("host " + key + " data " + cur_val);
          $("#bandwidth").val(cur_val);
        }
        $('#host-dialog-form').data('host_name', key).dialog('open');
      }
    });
  }

  function getPutLink(from, to) {
    $.ajax({
      type: 'GET',
      dataType: 'json',
      url: '/links/from/' + from + '/to/' + to,
      success: function(data) {
        window.console.log("data " + data['from'] + " " + data['bwidth']);
        $('#link_bandwidth').val(10.0);
        if (data['bwidth']) {
          var cur_val = parseFloat(data['bwidth']);
          window.console.log("cur_val is " + cur_val);
          $('#link_bandwidth').val(cur_val);
        }
        $('#link-dialog-form').dialog({title: "Assign Bandwidth for link " + data['from'] + "=>" + data['to']});
        $('#link-dialog-form').data('from', data['from']).data('to', data['to']).dialog('open');
      }
    });
  }

  Number.prototype.round = function(places){
    places = Math.pow(10, places); 
    return Math.round(this * places)/places;
  }

  function unit_of(num) {
    res = {};
    if (num >=0 && num < Math.pow(10, 6)) {
      res = { 
        unit: "KB",
        num_to_unit: (num / Math.pow(10, 3)).round(2)
      };
    } else if (num >= Math.pow(10, 6) && num < Math.pow(10, 9)) {
      res = {
        unit: "MB",
        num_to_unit: (num / Math.pow(10, 6)).round(2)
      };
    } else if (num >= Math.pow(10, 9) && num < Math.pow(10, 12)) {
      res = {
        unit: "GB",
        num_to_unit: (num / Math.pow(10, 9)).round(2) 
      };
    } else if (num >= Math.pow(10, 12) && num < Math.pow(10, 15)) {
      res = {
        unit: "PB",
        num_to_unit: (num / Math.pow(10, 12)).round(2)
      };
    }
    return res;
  }
}(jQuery, window));

