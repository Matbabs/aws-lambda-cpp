import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'app-loader',
  templateUrl: './loader.component.html',
  styleUrls: ['./loader.component.css']
})
export class LoaderComponent implements OnInit {

  @Input() text!: string;
  @Input() numbers!: number;
  @Input() numbersTotal!: number;

  constructor() { }

  ngOnInit(): void { }

  treatmentProportion() {
    return this.numbers * 100 / this.numbersTotal;
  }

}
