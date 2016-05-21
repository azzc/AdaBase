---
title: Fetch entire result set at once
---

<div class="leftside">
<pre class="code">
package AdaBase.Results.Sets is
   type Datarow        is tagged limited private;
   type Datarow_Access is access all Datarow;
   type Datarow_Set    is array (Positive range <>) of Datarow_Access;
end AdaBase.Results.Sets;
</pre>
<h3>AdaBase.Results.Sets.Datarow_Set function<br/>
AdaBase.Statement.Base.[STMT].fetch_all ()</h3>
<p>
This function retrieves the entire result set from a query at once (or the
remaining rows of data if some data has already been fetched).  The Datarow_Set
is an array of rows that is indexed started from 1, and the number of rows is
easily determined by the standard Length attribute of Ada arrays.
</p>
<p>
With the SQLite driver, the result set is limited to the first 20,000 rows.
</p>
<br/>
<p class="caption">See {{ page.query_select }} for a usage example.</p>
<br/>
<p>{{ page.supported_stmts }}</p>
</div>
<div class="sidenav">
  <h3>See Also</h3>
  <ul>
    <li>{{ page.fetch_bound }}</li>
    <li>{{ page.fetch_next }}</li>
    <li>{{ page.query_select }}</li>
    <li>{{ page.query }}</li>
  </ul>
</div>