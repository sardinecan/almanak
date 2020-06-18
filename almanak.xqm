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

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace file = "http://expath.org/ns/file";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace web = "http://basex.org/modules/web";
declare namespace update = "http://basex.org/modules/update";
declare namespace db = "http://basex.org/modules/db";

declare default element namespace "alm";
declare default function namespace "alm";

declare namespace xlink = "http://www.w3.org/1999/xlink" ;
declare namespace ev = "http://www.w3.org/2001/xml-events" ;
declare namespace xf = "http://www.w3.org/2002/xforms" ;
declare namespace eac = "eac" ;

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
 : @return create the db
 :
 : @todo create the prosopo db
 :)
declare 
  %rest:path("/almanak/install")
  %output:method("xml")
  %updating
function install() {
  if (db:exists("almanak")) 
    then (
      update:output("La base 'almanak' existe déjà, voulez-vous l’écraser ?")
     )
    else (
      update:output("La base a été créée"),
      db:create( "almanak", <alm xmlns='alm'/>, "almanak.xml", map {"chop" : fn:false()} )
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
  web:redirect("/almanak/list") 
};

(:~
 : This resource function lists all the almanachs
 : @return an ordered list of directories
 :)
declare 
%rest:path("/almanak/xml")
%rest:produces('application/xml')
%output:method("xml")
function list() {
  db:open('almanak')
};

(:~
 : This resource function edits a directory
 : @param a directory id
 : @return an xforms for the directory
:)
declare
  %rest:path("almanak/new")
  %output:method("xml")
function new() {
  let $content := map {
    'instance' : '',
    'model' : 'almanak_model.xml',
    'form' : 'almanak_form.xml'
  }
  let $outputParam := map {
    'layout' : "template.xml"
  }
  return
    (processing-instruction xml-stylesheet { fn:concat("href='", $dir:xsltFormsPath, "'"), "type='text/xsl'"},
    <?css-conversion no?>,
    wrapper($content, $outputParam)
    )
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
  %updating
function putAlmanak($param, $referer) {
  let $db := db:open("almanak")
  return
    if (fn:ends-with($referer, 'modify'))
    then
      let $location := fn:analyze-string($referer, 'almanak/(.+?)/modify')//fn:group[@nr='1']
      let $id := fn:replace(fn:lower-case($param/almanak/header/unitid), '/', '-')
      return (
        replace node $db/alm/almanak[@xml:id = $location] with $param,
        update:output(
         (
          <rest:response>
            <http:response status="200" message="test">
              <http:header name="Content-Language" value="fr"/>
              <http:header name="Content-Type" value="text/plain; charset=utf-8"/>
            </http:response>
          </rest:response>,
          <result>
            <id>{$id}</id>
            <message>La ressource a été modifiée.</message>
            <url></url>
          </result>
         )
        )
      )
    else
      let $id := fn:replace(fn:lower-case($param/almanak/header/unitid), '/', '-')
      let $param :=
        copy $d := $param
        modify (
          insert node attribute xml:id {$id} into $d/*
        )
        return $d
      return (
        insert node $param into $db/alm,
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
      modify replace value of node $doc/xf:model/xf:instance[@id=fn:substring-before($model, 'Model.xml')]/@src with '/xpr/' || $path || '/' || $instances[$i]
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