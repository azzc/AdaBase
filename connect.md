---
title: Connect to database
---

<div class="leftside">
<pre class="code">
package AdaBase is
   subtype PosixPort is Natural range 0 .. 65535;
end AdaBase;
</pre>
<h3>Procedure<br/>
AdaBase.Driver.Base.[DB].basic_connect (database, username, password, hostname : String; port : PosixPort)</h3>
<p>This procedure initiates a persistent connection to the database server.
The connection can be explicitly closed using the <b>disconnect</b> procedure,
and it will be automatically closed if the driver object is destroyed.
Attempting to open a connecton when one is already open will be ignored
and the attempt logged.  All connection failures will also be logged, followed
by an exception which cannot be ignored.</p>
<br/>
<h3>Procedure<br/>
AdaBase.Driver.Base.[DB].basic_connect (database, username, password, socket : String)</h3>
<p>This overloaded version of connect supports the use of UNIX sockets on the
localhost instead of host plus TCP/IP port.</p>
<pre class="code">
--  Used for all testcases for MySQL driver
--  DR is a variable of type AdaBase.Driver.Base.MySQL.MySQL_Driver

package body Connect is

   procedure connect_database is
   begin
      DR.basic_connect (database => "adabase_examples",
                        username => "root",
                        password => "",
                        hostname => "localhost",
                        port     => 3306);
   end connect_database;

end Connect;
</pre>
<br/>
<p class="caption">See {{ page.execute }} for a usage example coupled with code above.</p>
<br/>
<p>{{ page.supported_drivers }}</p>
</div>
<div class="sidenav">
  <h3>See Also</h3>
  <ul>
    <li>{{ page.disconnect }}</li>
    <li>{{ page.execute }}</li>
    <li>{{ page.query }}</li>
    <li>{{ page.commit }}</li>
    <li>{{ page.rollback }}</li>
  </ul>
</div>