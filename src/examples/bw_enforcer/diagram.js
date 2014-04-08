(function($, window) {

  var stage,
      Node = window.Node,
      Segment = window.Segment;

  var NODE_DIMENSIONS = {
    w: 50,
    h: 50
  };

  function initialize() {
    stage = $('#stage');

    var nodeE1 = new Node({
      title: 'e1',
      stage: stage,
      w: NODE_DIMENSIONS.w,
      h: NODE_DIMENSIONS.h,
      x: 100,
      y: 125,
      events: {
        click: function() {
          window.console.log(this);
        }
      }
    }).attach();

    var nodeC1 = new Node({
      title: 'c1',
      stage: stage,
      w: NODE_DIMENSIONS.w,
      h: NODE_DIMENSIONS.h,
      x: 200,
      y: 50
    }).attach();

    var nodeC3 = new Node({
      title: 'c3',
      stage: stage,
      w: NODE_DIMENSIONS.w,
      h: NODE_DIMENSIONS.h,
      x: 200,
      y: 200
    }).attach();

    var nodeC2 = new Node({
      title: 'c2',
      stage: stage,
      w: NODE_DIMENSIONS.w,
      h: NODE_DIMENSIONS.h,
      x: 400,
      y: 50
    }).attach();

    var nodeC4 = new Node({
      title: 'c4',
      stage: stage,
      w: NODE_DIMENSIONS.w,
      h: NODE_DIMENSIONS.h,
      x: 400,
      y: 200
    }).attach();

    var nodeE2 = new Node({
      title: 'e2',
      stage: stage,
      w: NODE_DIMENSIONS.w,
      h: NODE_DIMENSIONS.h,
      x: 500,
      y: 125 
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeE1,
      destination: nodeC1
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeE1,
      destination: nodeC3
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeC1,
      destination: nodeC2
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeC1,
      destination: nodeC3
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeC2,
      destination: nodeC4
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeC3,
      destination: nodeC4
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeC2,
      destination: nodeE2
    }).attach();

    new Segment({
      h: 5,
      stage: stage,
      origin: nodeC4,
      destination: nodeE2
    }).attach();

  }

  initialize();

}(jQuery, window));
