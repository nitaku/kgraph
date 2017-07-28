// Version 2.3 "inline" 28/07/2017
{
  var plain_text_offset = 0;
  var unidentified_span_next_id = 0;
  var unidentified_spans_stack = [];
  var open_spans = {};
  var result = {
    spans: [],
    plain_text: ""
  };
  var last_span = undefined;
}

start = Doc {
  return result;
}

Doc 'document'
  = (Text / SpanOpen / SpanClose)*

SpanOpen = id:SpanOpenCode {
  if(id === "") {
    // store unidentified spans in stack
    unidentified_spans_stack.push({
      start: plain_text_offset,
      start_code_location: location()
    });
  }
  else {
    // store identified spans in an index
    open_spans[id] = {
      id: id,
      start: plain_text_offset,
      start_code_location: location()
    };
  }
}
SpanClose = d:SpanCloseCode {
  var id = d.id;
  
  if(id in open_spans) {
    // span found in index: move it to results
    last_span = open_spans[id];
    delete open_spans[id];
  }
  else {
    if(unidentified_spans_stack.length === 0) {
      error('Trying to close a span without opening it.');
    }
    else {
      // span found in stack: move it to results
      last_span = unidentified_spans_stack.pop();

      // give unidentified spans an ID (underscore as first character is not allowed by syntax)
      if(id === '') {
        id = '_'+unidentified_span_next_id;
        unidentified_span_next_id += 1;
      }
      last_span.id = id;
    }
  }

  last_span.end = plain_text_offset;
  last_span.end_code_location = location();
  last_span.text = result.plain_text.slice(last_span.start, last_span.end);
  
  if(d.body !== undefined) {
    last_span.body = d.body;
  }
  
  result.spans.push(last_span);
}

Text = NoSpanCode {
  result.plain_text += text();
  plain_text_offset += text().length;
}

NoSpanCode = (!SpanCode .)+ { return text(); }
SpanCode = SpanOpenCode / SpanCloseCode

SpanOpenCode = '<' id:NullableId '<' { return id; }
SpanCloseCode =
  '>' id:NullableId '>' body:Body?
  {
    return {id: id, body: body};
  }
  
Body = BodyOpenCode body:NoBodyCode BodyCloseCode { return body; }

NullableId 'nullable identifier'
  = $(Id / '') { return text(); }

Id 'identifier'
  = [a-zA-Z0-9][_a-zA-Z0-9]* { return text(); }

NoBodyCode = (!BodyCode .)+ { return text(); }
BodyCode = BodyOpenCode / BodyCloseCode

BodyOpenCode = '('
BodyCloseCode = ')'