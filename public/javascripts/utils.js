jQuery(function ($) {
  $('.checkall').click(function () {
  	$(this).parents('form').find(':checkbox').attr('checked', this.checked);
  });

  $('.checksend').live('click', function (e){
    $("form").attr("action",$(this).attr("href")).submit();
    return false;
  });
});