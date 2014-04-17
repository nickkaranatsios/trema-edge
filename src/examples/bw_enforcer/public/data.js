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
            h: 5,
            stage: stage,
            origin: h_nodes[from],
            destination: h_nodes[to] 
          }).attach();
        } else {
          host_node = new Node({
            type: 'host',
            title: to,
            stage: stage,
            w: NODE_DIMENSIONS.w / 2,
            h: NODE_DIMENSIONS.h / 2,
            x: start_x,
            y: start_y
          }).attach();
          start_x += 100;
          new Segment({
            type: 'segment',
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
        var node_data="Stats:</br>";
        $(node.segments).each(function(i, seg) {
          dst_node = seg.destination;
          if (node.title == dst_node.title) {
            return;
          }
          pkts = pkt_count(data, dst_node.title);
          node_data += node.title + "=>" + dst_node.title + ":pkt_count(" + pkts + ") cost(" + link_cost(data, dst_node.title) + ")</br>";
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

  function pkt_count(data, to) {
    var pkts = "";
    var links = jQuery.parseJSON(data);
    $(links).each(function(i, link) {
      if (link['to'] == to) {
        pkts = link['packet_count'];
      }
    });
    return pkts;
  }

  function link_cost(data, to) {
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
  
}(jQuery, window));
