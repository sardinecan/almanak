xquery version "3.0";
module namespace dir = "alm";
(:~
 : This xquery module is an application for the analysis of historical almanachs
 :
 : @author sardinecan & emchateau (ANR Experts)
 : @since 2020-01
 : @licence GNU http://www.gnu.org/licenses
 :
 : xpr is free software: you can redistribute it and/or modify
 : it under the terms of the GNU General Public License as published by
 : the Free Software Foundation, either version 3 of the License, or
 : (at your option) any later version.
 :
 :)
import module namespace Session = 'http://basex.org/modules/session';

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace file = "http://expath.org/ns/file";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace web = "http://basex.org/modules/web";
declare namespace update = "http://basex.org/modules/update";
declare namespace db = "http://basex.org/modules/db";
declare namespace perm = "http://basex.org/modules/perm" ;
declare namespace user = "http://basex.org/modules/user" ;
declare namespace session = 'http://basex.org/modules/session' ;
declare namespace http = "http://expath.org/ns/http-client" ;

declare default element namespace "http://www.tei-c.org/ns/1.0";
declare default function namespace "alm";

declare namespace xlink = "http://www.w3.org/1999/xlink" ;
declare namespace ev = "http://www.w3.org/2001/xml-events" ;
declare namespace xf = "http://www.w3.org/2002/xforms" ;
declare namespace eac = "eac" ;
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare default collation "http://basex.org/collation?lang=fr";

declare variable $dir:xsltFormsPath := "/almanak/files/xsltforms/xsltforms.xsl";

(:~
 : This resource function defines the application root
 : @return redirect to the home page or to the install
 :)
declare 
  %rest:path("/almanak")
  %output:method("xml")
function index() {
  if (db:exists("almanak"))
    then web:redirect("/almanak/home")
    else web:redirect("/almanak/install") 
};

(:~
 : This resource function install
 : @return create the almanak db db
 :)
declare 
  %rest:path("/almanak/install")
  %output:method("xml")
  %perm:allow("almanak")
  %updating
function install() {
  if (db:exists("almanak")) 
    then (
      update:output("La base 'almanak' existe déjà")
     )
    else (
      update:output("La base a été créée"),
      db:create(
          'almanak',
          '/Volumes/data/github/experts/xprdata/almanak/almanak.xml',
          'almanak.xml',
          map{
            'ftindex': fn:true(),
            'stemming': fn:true(),
            'casesens': fn:true(),
            'diacritics': fn:true(),
            'language': 'fr',
            'updindex': fn:true(),
            'autooptimize': fn:true(),
            'maxlen': 96,
            'maxcats': 100,
            'splitsize': 0,
            'chop': fn:false(),
            'textindex': fn:true(),
            'attrindex': fn:true(),
            'tokenindex': fn:true(),
            'xinclude': fn:true()
          }
      )
    )
};

(:~
 : This resource function defines the application home
 : @return redirect to the directories list
 :)
declare
  %rest:path("/almanak/home")
  %output:method("xml")
function home() {
  web:redirect("/almanak/view")
};

(:~
 : This resource function lists all the almanachs
 : @return an ordered list of almanachs in html
 :)
declare
%rest:path("/almanak/view")
%rest:produces('application/xml')
%output:method("html")
function getAlmanakHtml() {
  <html>
    <head>
      <title>xpr AlmanaK</title>
      <meta charset="utf-8"/>
    </head>
    <body>
      <div>
        <h1>Liste des Almanachs</h1>
        <ul>{
          for $almanak in db:open('almanak')//TEI
          return <li>{$almanak//titleStmt/title[1]=> fn:normalize-space()} : <a href="/almanak/{$almanak/@xml:id}/modify">voir</a></li>
        }</ul>
      </div>
    </body>
  </html>
};

(:~
 : This resource function lists all the almanachs
 : @return an ordered list of almanach in xml
 :)
declare 
%rest:path("/almanak/xml")
%rest:produces('application/xml')
%output:method("xml")
function list() {
  db:open('almanak')
};

(:~
 : This resource function edits a new almanach
 : @return an xforms for the almanach
:)
declare
  %rest:path("almanak/new")
  %output:method("xml")
  %perm:allow("almanak")
function new() {
  let $content := map {
    'instance' : '',
    'model' : 'almanak_model.xml',
    'form' : 'almanak_form.xml'
  }
  let $outputParam := map {
    'layout' : "template.xml"
  }
  return(
    processing-instruction xml-stylesheet { fn:concat("href='", $dir:xsltFormsPath, "'"), "type='text/xsl'"},
    <?css-conversion no?>,
    wrapper($content, $outputParam)
  )
};

(:~
 : This resource function returns an almanach item
 : @param $id the almanach id
 : @return an almanach item in xml
 :)
declare
  %rest:path("almanak/{$id}")
  %output:method("xml")
function getAlmanak($id) {
  db:open('almanak')//TEI[@xml:id=$id]
};

(:~
 : This resource function returns an almanach item for an xforms instance
 : @return an xml resources
 :)
declare
  %rest:path("/almanak/xforms")
  %rest:produces('application/xml')
  %output:method("xml")
function getDataFromXforms() {
  let $id := request:parameter('data')
  let $almanak := db:open('almanak')//TEI[@xml:id = $id]
  return
    copy $d := $almanak
    modify (
      delete node $d/@xml:id
    )
    return $d
};

(:~
 : This resource function edits an almanachs
 : @param a directory id
 : @return an xforms for the almanachs
:)
declare
  %rest:path("almanak/{$id}/modify")
  %output:method("xml")
  %perm:allow("almanak")
function modifyAlmanak($id) {
  let $content := map {
    'instance' : $id,
    'path' : 'almanak',
    'model' : 'almanak_model.xml',
    'form' : 'almanak_form.xml'
  }
  let $outputParam := map {
    'layout' : "template.xml"
  }
  return(
    processing-instruction xml-stylesheet { fn:concat("href='", $dir:xsltFormsPath, "'"), "type='text/xsl'"},
    <?css-conversion no?>,
    wrapper($content, $outputParam)
  )
};

(:~ Login page (visible to everyone). :)
declare
  %rest:path("almanak/login")
  %output:method("html")
function login() {
  <html>
    Please log in:
    <form action="/almanak/login/check" method="post">
      <input name="name"/>
      <input type="password" name="pass"/>
      <input type="submit"/>
    </form>
  </html>
};

declare
  %rest:path("almanak/login/check")
  %rest:query-param("name", "{$name}")
  %rest:query-param("pass", "{$pass}")
function login($name, $pass) {
  try {
    user:check($name, $pass),
    Session:set('id', $name),
    web:redirect("/almanak/view")
  } catch user:* {
    web:redirect("/")
  }
};

(:~
 : Permissions: almanch
 : Checks if the current user is granted; if not, redirects to the login page.
 : @param $perm map with permission data
 :)
declare
    %perm:check('almanak', '{$perm}')
function permAlmanak($perm) {
  let $user := Session:get('id')
  return
    if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)) and fn:ends-with($perm?path, 'new'))
      then web:redirect('/almanak/login')
    else if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)) and fn:ends-with($perm?path, 'modify'))
      then web:redirect('/almanak/login')
    else if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)) and fn:ends-with($perm?path, 'put'))
      then web:redirect('/almanak/login')
    else if((fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)) and fn:ends-with($perm?path, 'install'))
      then web:redirect('/almanak/login')
};

(:~
 : This function creates new almanak
 : @param $param content to insert in the database
 : @param $refere the callback url
 : @return update the database with an updated content and an 200 http
 : @bug change unitid and @xml:id doesn't work ?
 :)
declare
  %rest:path("almanak/put")
  %output:method("xml")
  %rest:header-param("Referer", "{$referer}", "none")
  %rest:PUT("{$param}")
  %perm:allow("expertises")
  %updating
function putAlmanak($param, $referer) {
  let $db := db:open("almanak")
  return
    if (fn:ends-with($referer, 'modify'))
    then
      let $location := fn:analyze-string($referer, 'almanak/(.+?)/modify')//fn:group[@nr='1']
      return (
        replace node $db/teiCorpus/TEI[@xml:id = $location] with $param,
        update:output(
         (
          <rest:response>
            <http:response status="200" message="test">
              <http:header name="Content-Language" value="fr"/>
              <http:header name="Content-Type" value="text/plain; charset=utf-8"/>
            </http:response>
          </rest:response>,
          <result>
            <id>{$location}</id>
            <message>La ressource a été modifiée.</message>
            <url></url>
          </result>
         )
        )
      )
    else
      let $id := fn:generate-id($param)
      let $param :=
        copy $d := $param
        modify (
          insert node attribute xml:id {$id} into $d/*
        )
        return $d
      return (
        insert node $param after $db/teiCorpus/teiHeader,
        update:output(
         (
          <rest:response>
            <http:response status="200" message="test">
              <http:header name="Content-Language" value="fr"/>
            </http:response>
          </rest:response>,
          <result>
            <id>{$id}</id>
            <message>La ressource a été créée.</message>
            <url></url>
          </result>
         )
        )
      )
};

(:~
 : ~:~:~:~:~:~:~:~:~
 : utilities 
 : ~:~:~:~:~:~:~:~:~
 :)

(:~
 : this function defines a static files directory for the app
 :
 : @param $file file or unknown path
 : @return binary file
 :)
declare
  %rest:path('almanak/files/{$file=.+}')
function dir:file($file as xs:string) as item()+ {
  let $path := file:base-dir() || 'files/' || $file
  return
    (
      web:response-header( map {'media-type' : web:content-type($path)}),
      file:read-binary($path)
    )
};

(:~
 : this function return a mime-type for a specified file
 :
 : @param  $name  file name
 : @return a mime type for the specified file
 :)
declare function dir:mime-type($name as xs:string) as xs:string {
    fetch:content-type($name)
};

(:~
 : this function call a wrapper
 :
 : @param $content the content to serialize
 : @param $outputParams the output params
 : @return an updated document and instantiated pattern
 :)
declare function wrapper($content as map(*), $outputParams as map(*)) as node()* {
  let $layout := file:base-dir() || "files/" || map:get($outputParams, 'layout')
  let $wrap := fn:doc($layout)
  let $regex := '\{(.+?)\}'
  return
    $wrap/* update (
      for $node in .//*[fn:matches(text(), $regex)] | .//@*[fn:matches(., $regex)]
      let $key := fn:analyze-string($node, $regex)//fn:group/text()
      return switch ($key)
        case 'model' return replace node $node with getModels($content)
        case 'trigger' return replace node $node with getTriggers($content)
        case 'form' return replace node $node with getForms($content)
        case 'data' return replace node $node with $content?data
        default return associate($content, $outputParams, $node)
      )
};

(:~
 : this function get the models
 :
 : @param $content the content params
 : @return the default models or its instance version
 : @bug not generic enough
 :)
declare function getModels($content as map(*)){
  let $instances := map:get($content, 'instance')
  let $path := map:get($content, 'path')
  let $models := map:get($content, 'model')
  for $model at $i in $models return
    if ($instances[$i])
    then (
      copy $doc := fn:doc(file:base-dir() || "files/" || $model)
      modify replace value of node $doc/xf:model/xf:instance[@id=fn:substring-before($model, '_model.xml')]/@src with '/almanak/' || $instances[$i]
      return $doc
    )
    else
    fn:doc(file:base-dir() || "files/" || $model)
};

(:~
 : this function get the models
 :
 : @param $content the content params
 : @return the default models or its instance version
 : @bug not generic enough
 :)
declare function getTriggers($content as map(*)){
  let $instance := map:get($content, 'instance')
  let $path := map:get($content, 'path')
  let $triggers := map:get($content, 'trigger')
  return if ($triggers) then fn:doc(file:base-dir() || "files/" || $triggers) else ()
};

(:~
 : this function get the forms
 :
 : @param $content the content params
 : @return the default forms or its instance version
 : @bug not generic enough
 :)
declare function getForms($content as map(*)){
  let $instance := map:get($content, 'instance')
  let $path := map:get($content, 'path')
  let $forms := map:get($content, 'form')
  return if ($forms) then fn:doc(file:base-dir() || "files/" || $forms) else ()
};

(:~
 : this function dispatch the content with the data
 :
 : @param $content the content to serialize
 : @param $outputParams the serialization params
 : @return an updated node with the data
 : @bug the behavior is not complete
 :) 
declare 
  %updating 
function associate($content as map(*), $outputParams as map(*), $node as node()) {
  let $regex := '\{(.+?)\}'
  let $keys := fn:analyze-string($node, $regex)//fn:group/text()
  let $values := map:get($content, $keys)
    return typeswitch ($values)
    case document-node() return replace node $node with $values
    case empty-sequence() return ()
    case text() return replace value of node $node with $values
    case xs:string return replace value of node $node with $values
    case xs:string+ return 
      if ($node instance of attribute()) (: when key is an attribute value :)
      then 
        replace node $node/parent::* with 
          element {fn:name($node/parent::*)} {
          for $att in $node/parent::*/(@* except $node) return $att, 
          attribute {fn:name($node)} {fn:string-join($values, ' ')},
          $node/parent::*/text()
          }
    else
      replace node $node with 
      for $value in $values 
      return element {fn:name($node)} { 
        for $att in $node/@* return $att,
        $value
      } 
    case xs:integer return replace value of node $node with xs:string($values)
    case element()+ return replace node $node with 
      for $value in $values 
      return element {fn:name($node)} { 
        for $att in $node/@* return $att, "todo"
      }
    default return replace value of node $node with 'default'
};