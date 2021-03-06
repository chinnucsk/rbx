function handlePaginationClick(new_page_index, pagination_container)
{
   get_replist(new_page_index + 1, false);
   return false;
}

function apply_types(data, ignTypes)
{
   $("#rbx_types").children().remove();
   $("#rbx_types").text("Types: ");
   $.each(data, function(i, type)
   {
      var checked = true;
      if (ignTypes.indexOf(type) >= 0)
      {
         checked = false;
      }
      $("#rbx_types").append($("<input type='checkbox'>").val(type).attr("checked", checked));
      $("#rbx_types").append($("<label>").text(type));
   });
}

function show_reports(reports)
{
   $("#rbx_reports").children().remove();
   $("#rbx_reports").append("<tr><th class=\"show_col\">Show</th><th class=\"no_col\">No</th><th class=\"type_col\">Type</th><th class=\"pid_col\">Pid</th><th class=\"date_col\">Date</th></tr>");
   $.each(reports, function(i, rec)
   {
      var recClass = "";
      if (rec.type == "error" || rec.type == "error_report" || rec.type == "error_msg" || rec.type == "crash_report")
      {
         recClass = "error";
      }
      if (rec.type == rec.type == "warning" || rec.type == "warning_report" || rec.type == "warning_msg")
      {
         recClass = "warning";
      }
      else if (rec.type == "progress")
      {
         recClass = "progress";
      }
      else if (rec.type == "info" || rec.type == "info_report" || rec.type == "info_msg")
      {
         recClass = "info";
      }
      $("#rbx_reports").append($("<tr class=\"" + recClass + "\"><td class=\"show_col\"><input id=\"rbx_show\" value=\"" +
         rec.no + "\" type=\"checkbox\"/></td><td>" + rec.no + "</td><td>" + rec.type + "</td><td>" + rec.pid + "</td><td>"
         + rec.date + "</td></tr>").click(function()
      {
         var recs = get_selected_reports();
         if (recs == "[]") // has no selected reports
         {
            recs = "[" + rec.no + "]";
         }
         var node = $("#rbx_node").val();
         $.post("/get_sel_reports", "{'" + node + "'," + recs + "}.", function(res)
         {
            var body = $("body", top.frames[1].document);
            body.children().remove();
            body.append(res);
         });
      }));
   });
}

function get_ignored_types()
{
   var arr = new Array();
   var cnt = 0;
   $("#rbx_types input").each(function(i, t)
   {
      if (t.checked == false)
      {
         arr[cnt++] = t.value;
      }
   });
   return arr;
}

function get_selected_reports()
{
   var res = "[";
   $("#rbx_reports #rbx_show").each(function(i, it)
   {
      if (it.checked == true)
      {
         if(res != "[")
         {
            res += ",";
         }
         res += it.value;
      }
   });
   return res + "]";
}

function get_replist(page, doPagination)
{
   var node = $("#rbx_node").val();
   var doRescan = $("#rbx_rescan").is(":checked");
   var maxReports = $("#rbx_max_reports").val();
   var recOnPage = $("#rbx_rec_on_page").val();
   var reg_exp = $("#rbx_grep").val();
   var recOnPage = $("#rbx_rec_on_page").val();
   var ignTypes = get_ignored_types();
   var ignTypesList ="[";
   $.each(ignTypes, function(i, t)
   {
      if (ignTypesList != "[")
      {
         ignTypesList += ",";
      }
      ignTypesList += t;
   });
   ignTypesList += "]";
   var request = "{clstate, \"" + reg_exp + "\"," + ignTypesList + ",'" + node + "'," + doRescan + "," + maxReports
      + "," + page + "," + recOnPage + "}.";
   $.post("/get_replist", request, function(res)
   {
      var data = jQuery.parseJSON(res);
      apply_types(data.rtypes, ignTypes);
      if (doPagination)
      {
         $("#pagination").pagination(data.reports_count,
         {
            items_per_page:recOnPage,
            callback:handlePaginationClick
         });
      }
      show_reports(data.reports);
   });
   var body = $("body", top.frames[1].document);
   body.children().remove();
}
function get_state()
{
   $.post("/get_state", "", function(res)
   {
      var data = jQuery.parseJSON(res);
      apply_types(data.rtypes, data.ignored_rtypes);
      $("#rbx_rescan").attr("checked", data.do_rescan);
      $("#rbx_max_reports").val(data.max_reports);
      $("#rbx_rec_on_page").val(data.rec_on_page);
      $("#rbx_grep").val(data.re);
      $.each(data.nodes, function(i, node)
      {
         $("#rbx_node").append("<option value=\"" + node + "\">" + node + "</option>");
      });
      $("#rbx_node").val(data.node);
      get_replist("1", true);
   });
}

$(document).ready(function()
{
   get_state();
   $("#rbx_show").click(function()
   {
      get_replist("1", true, null);
   });
});
