import { Template } from 'meteor/templating';
 
import { Notes } from '../../../api/notes/notes.js';
 
import './importer.jade';

Template.importer.events({
  'click input.submit'(event) {
    event.preventDefault();
    let data = {}
    data.importLines = $(event.currentTarget).siblings('textarea').get(0).value.split('\n');
    $(event.currentTarget).siblings('textarea').get(0).value = '';
    data.prevLevel = 0;
    data.prevParents = [];
    data.levelRanks = [];
    Template.importer.import(data);
  },
});

Template.importer.import = function(data,row=0,lastNote=null) {
  console.log(data);
  console.log(row);
  for (let ii = row; ii < data.importLines.length; ii++) {
      let line = data.importLines[ii];
      if (line.trim().substr(0,1)!="-") {
        // Invalid line
        continue;
      }
      console.log(line);
      let leadingSpaceCount = line.match(/^(\s*)/)[1].length
      let level = leadingSpaceCount/4;
      let parent = null;
      if (level > 0) {
        // Calculate parent
        if (level > data.prevLevel) {
          // This is a new depth, look at the last added note
          parent = lastNote;
          data.prevParents[level] = parent;
        } else {
          //  We have moved back out to a higher level
          parent = data.prevParents[level];
        }
      }
      data.prevLevel = level;
      if (data.levelRanks[level]) {
        data.levelRanks[level]++;
      } else {
        data.levelRanks[level] = 1;
      }
      let title = line.substr(2 + (level * 4));
      // Check if the next line is a body
      let nextLine = data.importLines[ii+1];
      var body = null;
      console.log(nextLine);
      if (nextLine && nextLine.trim().substr(0,1)=="\"") {
        console.log("Got a body");
        body = nextLine.trim().substr(1);
        body = body.substr(0,body.length);
        console.log(body);
      }
      Meteor.call('notes.insert',title,data.levelRanks[level],parent,level,function(err,res) {
        console.log("Res: ",res);
        if (body) {
          console.log("Save!");
          Meteor.call('notes.updateBody',res,body);
        }
        Template.importer.import(data,ii + 1,res);
      });
      break;
    }
};

Template.importer.helpers({
  'bulletClass'() {
    if (this.children > 0) {
      return 'hasChildren';
    }
  },
});