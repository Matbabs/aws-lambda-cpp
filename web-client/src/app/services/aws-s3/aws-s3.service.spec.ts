import { TestBed } from '@angular/core/testing';

import { AwsS3Service } from './aws-s3.service';

describe('AwsS3Service', () => {
  let service: AwsS3Service;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(AwsS3Service);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
