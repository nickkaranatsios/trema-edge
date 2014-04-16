$(function() {
  $.ajaxSetup({
    dataType: 'text',
    error: function(xhr, status, error) {
      info('Error! ' +  ( error ? error : xhr.status ));
    }
  });

  function info(text) {
    $('#info-text').text(text);
  }

  $.getJSON('/topology', function(data) {
  });

});
