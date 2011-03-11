add_visual_data = function() {
  var items = document.documentElement.getElementsByTagName('*');
  var i=0;
  for(var i=0; i<items.length; i++) {
    var item = items[i];
    item.setAttribute('vx', item.offsetLeft);
    item.setAttribute('vy', item.offsetTop);
    item.setAttribute('vw', item.offsetWidth);
    item.setAttribute('vh', item.offsetHeight);
    item.setAttribute('vsize', document.defaultView.getComputedStyle(item, null).getPropertyValue('font-size'));
    var weight = document.defaultView.getComputedStyle(item, null).getPropertyValue('font-weight');
    if (weight == 'normal') weight = 400;
    if (weight == 'bold')   weight = 700;
    item.setAttribute('vweight', weight);
    item.setAttribute('vcolor', document.defaultView.getComputedStyle(item, null).getPropertyValue('color'));
    item.setAttribute('vbcolor', document.defaultView.getComputedStyle(item, null).getPropertyValue('background-color'));
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