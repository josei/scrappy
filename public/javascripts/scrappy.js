add_visual_data = function() {
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

$(document).ready(function(){
  $("body").append("<div id='myTrees'></div>")
	$("#page > *").bind('mouseover', function(e){
	e.stopPropagation();
		$(this).addClass("changeBg");
		})
		.mouseout(function(){
		$(this).removeClass("changeBg");
		});        
});

$(document).ready(function(){
  $("*").bind('click', function(e){
    e.stopPropagation();
    var element = $(e.target).closest(this.tagName).get(0).tagName;
    var parents = $(this).parents();
    var string = element.toString();
    for(j=0;j<parents.length;j++) {
      string = string + " " + parents[j].tagName;
    }      
    
    var tree = [];
    var treeString = "";
    for(h=parents.length-1; h>=0; h-- ) {
      tree.push(parents[h].tagName);
      
      if( treeString == "" ) {
        treeString = treeString + parents[h].tagName;
      } else {
        treeString = treeString + " > " + parents[h].tagName;      
      }
    }                                 
    
    tree.push(element);
    treeString = treeString + " > " + element;
    
    var myTrees = document.getElementById("myTrees");
    var ul = document.createElement("ul");
    var li = document.createElement("li");
    myTrees.appendChild(ul);
    li.innerHTML = treeString;
    myTrees.appendChild(li);
  });
});

window.scrappy_loaded = true