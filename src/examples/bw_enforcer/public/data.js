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

  $.getJSON('/topology', function(data) {
    var nodes = data['topo-keys']
    var start_x = 200, start_y = 200
    var h_nodes = {}

    stage = $('#stage');
    $(nodes).each(function(i, item) {
      window.console.log(item);
      var links = jQuery.parseJSON(data[item]);
      window.console.log(Object.prototype.toString.call(links));
      window.console.log(data[item]);
      h_nodes[item] = new Node({
        title: item,
        stage: stage,
        w: NODE_DIMENSIONS.w,
        h: NODE_DIMENSIONS.h,
        x: start_x,
        y: start_y,
        events: {
          click: function() {
            // window.console.log(this);
            get_node_info(this, item);
          }
        }
      }).attach();
      start_x += 100
    });
    $(nodes).each(function(i, item) {
      var links = jQuery.parseJSON(data[item]);
      $(links).each(function(j, link) {
        from = link['from'];
        to = link['to'];
        if ( from in h_nodes && to in h_nodes ) {
          new Segment({
            h: 5,
            stage: stage,
            origin: h_nodes[from],
            destination: h_nodes[to] 
          }).attach();
        }
      });
    });
  });

  function get_node_info(node, key) {
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
          //pkts = 1;
          node_data += node.title + "=>" + dst_node.title + ":pkt_count(" + pkts + ")</br>";
        });
        node.el.append('<h5>' + node_data + '</h5>');
        window.console.log(data);
      }
    });
  }

  function pkt_count(data, to) {
    var pkts = "";
    var links = jQuery.parseJSON(data);
    $(links).each(function(i, link) {
      if (link['to'] == to) {
        window.console.log(link['to'] == to);
        pkts = link['packet_count'];
      }
    });
    return pkts;
  }

  function display_node_info(data) {
    window.console.log(Node);
  }
  
}(jQuery, window));
