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
