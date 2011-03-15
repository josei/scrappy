var add_visual_data = function() {
  var items = document.documentElement.getElementsByTagName('*');
  var i=0;
  for(var i=0; i<items.length; i++) {
    var item = items[i];
    var x = 0;
    var y = 0;
    if (item.offsetParent) {
      var obj = item;
      do {
			  x += obj.offsetLeft;
			  y += obj.offsetTop;
		  } while (obj = obj.offsetParent);
	  }
    item.setAttribute('vx', x);
    item.setAttribute('vy', y);
    item.setAttribute('vw', item.offsetWidth);
    item.setAttribute('vh', item.offsetHeight);
    var size = document.defaultView.getComputedStyle(item, null).getPropertyValue('font-size');
    size = size.substring(0, size.length-2);
    item.setAttribute('vsize', size);
    var weight = document.defaultView.getComputedStyle(item, null).getPropertyValue('font-weight');
    if (weight == 'normal') weight = 400;
    if (weight == 'bold')   weight = 700;
    item.setAttribute('vweight', weight);
  }
}


jQuery(document).ready(function(){
  var div;
  if (window.scrappy_extractor) {
    div = "<div id='scrappy_window' title='Scrappy'>" +
          "<p>Extractor available for this URL</p>" +
          "<p><a href='http://localhost:3434/rdf/"+escape(window.location)+"'>See output</a></p>" +
          "<p><a class='sample' href='http://localhost:3434/samples'>Upload sample</a></p>" +
          "</div>";
  } else {
    div = "<div id='scrappy_window' title='Scrappy'>" +
          "<p>No extractor available for this URL</p>" +
          "<p><a href='TODO'>Annotate page</a></p>" +
          "<p><a class='extractor' href='http://localhost:3434/extractors'>Generate extractor</a></p>" +
          "</div>";
  }
  
  $("body").append(div);
  
  $('#scrappy_window .extractor, #scrappy_window .sample').live('click', function (e){
    var link = $(this),
        href = link.attr('href'),
        html = $('<input name="html" type="hidden" />');
        uri  = $('<input name="uri"  type="hidden" />');
        form = $('<form method="post" action="'+href+'"></form>');
    html.attr('value', document.documentElement.outerHTML);
    uri.attr('value', window.location);
    form.hide()
        .append(html)
        .append(uri)
        .appendTo('body');
    e.preventDefault();
    form.submit();
  });
  
  $("#scrappy_window").dialog();
});

add_visual_data();

window.scrappy_loaded = true